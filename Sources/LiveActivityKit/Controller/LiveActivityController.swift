import Foundation
import Observation

/// What runs Live Activities for a ``LiveActivityController``: ActivityKit on iOS (``ActivityKitBackend``), or
/// ``InMemoryActivityBackend`` in previews, tests and on the Mac.
public protocol LiveActivityBackend<Attributes>: Sendable {
    associatedtype Attributes: LiveActivityAttributes

    /// `false` when the user turned Live Activities off for the app or the device has none.
    var areActivitiesEnabled: Bool { get }

    /// Starts an activity and returns its id. With `pushUpdates`, the system hands out a push token for it.
    func request(
        attributes: Attributes,
        content: LiveActivityContent<Attributes.ContentState>,
        pushUpdates: Bool
    ) throws -> String

    /// Updates the activity with `id`, optionally with an alert.
    func update(id: String, content: LiveActivityContent<Attributes.ContentState>, alert: LiveActivityAlert?) async

    /// Ends the activity with `id`, optionally with final content that stays on the Lock Screen until `dismissal`.
    func end(id: String, content: LiveActivityContent<Attributes.ContentState>?, dismissal: LiveActivityDismissal) async

    /// The activity's push tokens as they arrive; ActivityKit can replace a token while the activity runs.
    func pushTokenUpdates(id: String) -> AsyncStream<Data>
}

/// What happened to an update.
public enum LiveActivityUpdateResult: String, Hashable, Sendable {
    /// The update was sent.
    case sent
    /// Skipped: nothing changed (see ``LiveActivityUpdatePolicy/ignoredKeys``).
    case unchanged
    /// Skipped: too soon after the last update (see ``LiveActivityUpdatePolicy/minimumInterval``).
    case throttled
    /// Skipped: no activity is running.
    case notRunning
}

/// Starts, updates and ends one Live Activity, and keeps what it last sent.
///
/// ```swift
/// // iOS
/// let controller = ActivityController<DeliveryActivityAttributes>()
/// try controller.start(attributes, state: state, pushUpdates: true)
/// controller.onPushToken = { token in api.register(token) }
///
/// await controller.update(nextState)                   // .sent, or .unchanged when nothing changed
/// await controller.update(arrived, alert: LiveActivityAlert(title: "Delivered", body: "Enjoy your meal"))
/// await controller.end(arrived, dismissal: .after(.now + 15 * 60))
/// ```
///
/// Every start and update gets a stale date from the ``policy`` unless you pass one, updates that change nothing are
/// skipped, and the push token arrives as hex. The controller is `@Observable`, so a view can show its state.
@MainActor
@Observable
public final class LiveActivityController<Backend: LiveActivityBackend> {
    public typealias Attributes = Backend.Attributes
    public typealias State = Backend.Attributes.ContentState

    /// Where activities run.
    public let backend: Backend
    /// Stale dates, skipped updates and throttling.
    public var policy: LiveActivityUpdatePolicy

    /// The id of the running activity, or `nil`.
    public private(set) var activityID: String?
    /// The attributes of the running activity.
    public private(set) var attributes: Attributes?
    /// The state last sent.
    public private(set) var state: State?
    /// The stale date last sent.
    public private(set) var staleDate: Date?
    /// When the activity was started or last updated.
    public private(set) var lastUpdate: Date?
    /// The latest push token of the running activity, as lowercase hex.
    public private(set) var pushToken: String?

    /// Called with every new push token, as lowercase hex, to send it to your server.
    @ObservationIgnored public var onPushToken: ((String) -> Void)?

    private let now: @Sendable () -> Date
    @ObservationIgnored private var tokenTask: Task<Void, Never>?

    /// - Parameter now: The clock; tests pass a fixed one.
    public init(
        backend: Backend,
        policy: LiveActivityUpdatePolicy = LiveActivityUpdatePolicy(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.policy = policy
        self.now = now
    }

    /// `true` while an activity runs.
    public var isActive: Bool {
        activityID != nil
    }

    /// `false` when Live Activities are turned off for the app.
    public var areActivitiesEnabled: Bool {
        backend.areActivitiesEnabled
    }

    /// How current the running activity's content is.
    public var freshness: LiveActivityFreshness {
        guard let lastUpdate else { return .fresh }
        return LiveActivityStaleness.freshness(updatedAt: lastUpdate, staleDate: staleDate, now: now())
    }

    /// Starts an activity.
    ///
    /// - Parameters:
    ///   - staleDate: When the content goes stale; `nil` uses ``LiveActivityUpdatePolicy/maxAge``.
    ///   - relevanceScore: Which activity the system shows first when several run.
    ///   - pushUpdates: Asks for a push token so your server can update the activity.
    /// - Throws: ``LiveActivityError/disabled``, ``LiveActivityError/alreadyRunning``, or the backend's error.
    @discardableResult
    public func start(
        _ attributes: Attributes,
        state: State,
        staleDate: Date? = nil,
        relevanceScore: Double = 0,
        pushUpdates: Bool = false
    ) throws -> String {
        guard backend.areActivitiesEnabled else { throw LiveActivityError.disabled }
        guard activityID == nil else { throw LiveActivityError.alreadyRunning }
        let date = now()
        let stale = policy.staleDate(explicit: staleDate, now: date)
        let content = LiveActivityContent(state: state, staleDate: stale, relevanceScore: relevanceScore)
        let id = try backend.request(attributes: attributes, content: content, pushUpdates: pushUpdates)
        activityID = id
        self.attributes = attributes
        self.state = state
        self.staleDate = stale
        lastUpdate = date
        pushToken = nil
        if pushUpdates {
            observePushTokens(of: id)
        }
        return id
    }

    /// Sends `state` to the running activity, unless the ``policy`` says to skip it.
    ///
    /// - Parameters:
    ///   - staleDate: When the content goes stale; `nil` uses ``LiveActivityUpdatePolicy/maxAge``.
    ///   - alert: Lights up the screen and expands the island; an update with an alert is always sent.
    ///   - force: Sends even when nothing changed or the last update was moments ago.
    @discardableResult
    public func update(
        _ state: State,
        staleDate: Date? = nil,
        relevanceScore: Double = 0,
        alert: LiveActivityAlert? = nil,
        force: Bool = false
    ) async -> LiveActivityUpdateResult {
        guard let id = activityID else { return .notRunning }
        let date = now()
        switch policy.decision(from: self.state, to: state, lastUpdate: lastUpdate, now: date, hasAlert: alert != nil, force: force) {
        case .unchanged:
            return .unchanged
        case .throttled:
            return .throttled
        case .send:
            break
        }
        let stale = policy.staleDate(explicit: staleDate, now: date)
        self.state = state
        self.staleDate = stale
        lastUpdate = date
        await backend.update(
            id: id,
            content: LiveActivityContent(state: state, staleDate: stale, relevanceScore: relevanceScore),
            alert: alert
        )
        return .sent
    }

    /// Ends the running activity. With a final state, it stays on the Lock Screen until `dismissal`.
    public func end(_ finalState: State? = nil, dismissal: LiveActivityDismissal = .default) async {
        guard let id = activityID else { return }
        let content = finalState.map { LiveActivityContent(state: $0, staleDate: nil) }
        activityID = nil
        attributes = nil
        if let finalState {
            state = finalState
        }
        staleDate = nil
        lastUpdate = now()
        tokenTask?.cancel()
        tokenTask = nil
        await backend.end(id: id, content: content, dismissal: dismissal)
    }

    private func observePushTokens(of id: String) {
        tokenTask?.cancel()
        let tokens = backend.pushTokenUpdates(id: id)
        tokenTask = Task { [weak self] in
            for await token in tokens {
                guard let self, self.activityID == id else { return }
                self.receivePushToken(token)
            }
        }
    }

    private func receivePushToken(_ token: Data) {
        let hex = PushToken.hexString(token)
        guard hex != pushToken else { return }
        pushToken = hex
        onPushToken?(hex)
    }
}

/// Runs activities in memory and records every call: for previews, tests, and platforms without ActivityKit.
///
/// ```swift
/// let backend = InMemoryActivityBackend<TimerActivityAttributes>()
/// let controller = LiveActivityController(backend: backend)
/// try controller.start(attributes, state: state)
/// backend.records.last?.kind    // .request
/// ```
public final class InMemoryActivityBackend<Attributes: LiveActivityAttributes>: LiveActivityBackend, @unchecked Sendable {
    /// One call to the backend.
    public struct Record: Sendable {
        public enum Kind: String, Sendable {
            case request
            case update
            case end
        }

        public let kind: Kind
        public let id: String
        public let content: LiveActivityContent<Attributes.ContentState>?
        public let alert: LiveActivityAlert?
        public let dismissal: LiveActivityDismissal?
    }

    private let lock = NSLock()
    private var enabled: Bool
    private var failure: (any Error)?
    private var nextNumber = 1
    private var running: [String: Attributes] = [:]
    private var recorded: [Record] = []
    private var tokenContinuations: [String: AsyncStream<Data>.Continuation] = [:]

    /// - Parameter enabled: What ``areActivitiesEnabled`` answers.
    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    public var areActivitiesEnabled: Bool {
        lock.withLock { enabled }
    }

    /// Turns Live Activities on or off, as the user can in Settings.
    public func setEnabled(_ enabled: Bool) {
        lock.withLock { self.enabled = enabled }
    }

    /// Makes the next request throw `error`, as ActivityKit does when too many activities run.
    public func failNextRequest(with error: any Error) {
        lock.withLock { failure = error }
    }

    /// Every call so far, oldest first.
    public var records: [Record] {
        lock.withLock { recorded }
    }

    /// The ids of the activities that are running.
    public var runningIDs: [String] {
        lock.withLock { running.keys.sorted() }
    }

    public func request(
        attributes: Attributes,
        content: LiveActivityContent<Attributes.ContentState>,
        pushUpdates: Bool
    ) throws -> String {
        try lock.withLock {
            if let failure {
                self.failure = nil
                throw failure
            }
            let id = "activity-\(nextNumber)"
            nextNumber += 1
            running[id] = attributes
            recorded.append(Record(kind: .request, id: id, content: content, alert: nil, dismissal: nil))
            return id
        }
    }

    public func update(id: String, content: LiveActivityContent<Attributes.ContentState>, alert: LiveActivityAlert?) async {
        lock.withLock {
            guard running[id] != nil else { return }
            recorded.append(Record(kind: .update, id: id, content: content, alert: alert, dismissal: nil))
        }
    }

    public func end(id: String, content: LiveActivityContent<Attributes.ContentState>?, dismissal: LiveActivityDismissal) async {
        let continuation: AsyncStream<Data>.Continuation? = lock.withLock {
            guard running.removeValue(forKey: id) != nil else { return nil }
            recorded.append(Record(kind: .end, id: id, content: content, alert: nil, dismissal: dismissal))
            return tokenContinuations.removeValue(forKey: id)
        }
        continuation?.finish()
    }

    public func pushTokenUpdates(id: String) -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        lock.withLock { tokenContinuations[id] = continuation }
        return stream
    }

    /// Hands out a push token for the activity with `id`, as the system does after a start with push updates.
    public func sendPushToken(_ token: Data, for id: String) {
        let continuation = lock.withLock { tokenContinuations[id] }
        continuation?.yield(token)
    }
}
