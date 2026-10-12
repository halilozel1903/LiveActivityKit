#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Runs Live Activities with ActivityKit.
///
/// The backend keeps no state: it finds a running activity by id in `Activity.activities`, so it also reaches
/// activities started before the app was relaunched.
public struct ActivityKitBackend<Attributes: LiveActivityAttributes & ActivityAttributes>: LiveActivityBackend {
    public init() {}

    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public func request(
        attributes: Attributes,
        content: LiveActivityContent<Attributes.ContentState>,
        pushUpdates: Bool
    ) throws -> String {
        do {
            let activity = try Activity<Attributes>.request(
                attributes: attributes,
                content: Self.activityContent(content),
                pushType: pushUpdates ? .token : nil
            )
            return activity.id
        } catch {
            throw LiveActivityError.requestFailed(error.localizedDescription)
        }
    }

    public func update(id: String, content: LiveActivityContent<Attributes.ContentState>, alert: LiveActivityAlert?) async {
        guard let activity = Self.activity(id: id) else { return }
        await activity.update(Self.activityContent(content), alertConfiguration: alert.map(Self.alertConfiguration))
    }

    public func end(id: String, content: LiveActivityContent<Attributes.ContentState>?, dismissal: LiveActivityDismissal) async {
        guard let activity = Self.activity(id: id) else { return }
        await activity.end(content.map(Self.activityContent), dismissalPolicy: Self.dismissalPolicy(dismissal))
    }

    public func pushTokenUpdates(id: String) -> AsyncStream<Data> {
        AsyncStream { continuation in
            let task = Task {
                guard let activity = Self.activity(id: id) else {
                    continuation.finish()
                    return
                }
                for await token in activity.pushTokenUpdates {
                    continuation.yield(token)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// The ids of this template's running activities, for example to end them all on launch.
    public var runningActivityIDs: [String] {
        Activity<Attributes>.activities.map(\.id)
    }

    // MARK: - Conversions

    private static func activity(id: String) -> Activity<Attributes>? {
        Activity<Attributes>.activities.first { $0.id == id }
    }

    private static func activityContent(
        _ content: LiveActivityContent<Attributes.ContentState>
    ) -> ActivityContent<Attributes.ContentState> {
        ActivityContent(state: content.state, staleDate: content.staleDate, relevanceScore: content.relevanceScore)
    }

    private static func alertConfiguration(_ alert: LiveActivityAlert) -> AlertConfiguration {
        AlertConfiguration(
            title: LocalizedStringResource(String.LocalizationValue(alert.title)),
            body: LocalizedStringResource(String.LocalizationValue(alert.body)),
            sound: alert.soundName.map { AlertConfiguration.AlertSound.named($0) } ?? .default
        )
    }

    private static func dismissalPolicy(_ dismissal: LiveActivityDismissal) -> ActivityUIDismissalPolicy {
        switch dismissal {
        case .default: return .default
        case .immediate: return .immediate
        case let .after(date): return .after(date)
        }
    }
}

/// A controller for ActivityKit activities of one template.
///
/// ```swift
/// let deliveries = ActivityController<DeliveryActivityAttributes>()
/// ```
public typealias ActivityController<Attributes: LiveActivityAttributes & ActivityAttributes> =
    LiveActivityController<ActivityKitBackend<Attributes>>

extension LiveActivityController {
    /// A controller backed by ActivityKit.
    public convenience init<A: LiveActivityAttributes & ActivityAttributes>(
        policy: LiveActivityUpdatePolicy = LiveActivityUpdatePolicy()
    )
    where Backend == ActivityKitBackend<A> {
        self.init(backend: ActivityKitBackend<A>(), policy: policy)
    }
}
#endif
