import Foundation

/// When an update to a running Live Activity is worth sending.
///
/// ActivityKit budgets updates, and every update redraws the Lock Screen and the Dynamic Island, so a controller
/// should skip updates that change nothing visible and space out frequent ones.
///
/// ```swift
/// let policy = LiveActivityUpdatePolicy(maxAge: 900, ignoredKeys: ["serverTimestamp"], minimumInterval: 5)
/// policy.decision(from: old, to: new, lastUpdate: last, now: .now, hasAlert: false)   // .send, .unchanged or .throttled
/// ```
public struct LiveActivityUpdatePolicy: Hashable, Sendable {
    /// How long content stays fresh without an update: each start or update gets a stale date this far ahead unless
    /// one is given. `nil` sets no stale date.
    public var maxAge: TimeInterval?
    /// Content state keys that do not justify an update on their own, such as a server timestamp.
    public var ignoredKeys: Set<String>
    /// The shortest time between two updates; closer updates are skipped unless they carry an alert or are forced.
    public var minimumInterval: TimeInterval

    public init(maxAge: TimeInterval? = 900, ignoredKeys: Set<String> = [], minimumInterval: TimeInterval = 0) {
        self.maxAge = maxAge
        self.ignoredKeys = ignoredKeys
        self.minimumInterval = minimumInterval
    }

    /// What to do with an update.
    public enum Decision: String, Hashable, Sendable {
        /// Send it.
        case send
        /// Skip it: nothing but ignored keys changed.
        case unchanged
        /// Skip it: the last update was less than ``LiveActivityUpdatePolicy/minimumInterval`` ago.
        case throttled
    }

    /// Whether to send `new` after `old` was sent at `lastUpdate`. An alert or `force` always sends, and an update
    /// that changes nothing is skipped before throttling is considered.
    public func decision<State: Encodable>(
        from old: State?,
        to new: State,
        lastUpdate: Date?,
        now: Date,
        hasAlert: Bool = false,
        force: Bool = false
    ) -> Decision {
        if force || hasAlert { return .send }
        if let old, !ContentStateDiff.hasChanges(from: old, to: new, ignoring: ignoredKeys) {
            return .unchanged
        }
        if let lastUpdate, minimumInterval > 0, now.timeIntervalSince(lastUpdate) < minimumInterval {
            return .throttled
        }
        return .send
    }

    /// The stale date for content sent at `now`: `explicit` when given, otherwise `now` plus ``maxAge``.
    public func staleDate(explicit: Date?, now: Date) -> Date? {
        if let explicit { return explicit }
        guard let maxAge else { return nil }
        return LiveActivityStaleness.staleDate(updatedAt: now, maxAge: maxAge)
    }
}
