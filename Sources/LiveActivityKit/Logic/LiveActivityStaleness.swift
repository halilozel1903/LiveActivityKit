import Foundation

/// How current a Live Activity's content is.
public enum LiveActivityFreshness: String, Hashable, Sendable, CaseIterable {
    /// Recently updated.
    case fresh
    /// Most of the way to its stale date: time to send an update.
    case aging
    /// Past its stale date. The system sets `isStale` on the activity context and views show a hint.
    case stale
}

/// Stale dates for `ActivityContent` and the checks behind them.
///
/// A stale date tells the system when the content shown is no longer trustworthy if no update arrives, for example
/// an ETA that has passed. Views get `context.isStale` and can say that they are waiting for an update.
///
/// ```swift
/// let stale = LiveActivityStaleness.staleDate(eta: eta, updatedAt: .now, grace: 600, maxAge: 1_800)
/// LiveActivityStaleness.isStale(staleDate: stale, now: .now)    // false
/// ```
public enum LiveActivityStaleness {
    /// `updatedAt` plus `maxAge` (negative ages count as zero).
    public static func staleDate(updatedAt: Date, maxAge: TimeInterval) -> Date {
        updatedAt.addingTimeInterval(maxAge.isNaN ? 0 : max(0, maxAge))
    }

    /// For content with an arrival time: stale `grace` seconds after `eta`, or `maxAge` after the update when that
    /// comes first. Without an ETA only the age counts.
    public static func staleDate(eta: Date?, updatedAt: Date, grace: TimeInterval, maxAge: TimeInterval) -> Date {
        let byAge = staleDate(updatedAt: updatedAt, maxAge: maxAge)
        guard let eta else { return byAge }
        let byETA = eta.addingTimeInterval(grace.isNaN ? 0 : max(0, grace))
        return min(byAge, byETA)
    }

    /// `true` from the stale date on. Content without a stale date never goes stale.
    public static func isStale(staleDate: Date?, now: Date) -> Bool {
        guard let staleDate else { return false }
        return now >= staleDate
    }

    /// Fresh, aging (past `agingShare` of the way from the update to the stale date) or stale.
    public static func freshness(
        updatedAt: Date,
        staleDate: Date?,
        now: Date,
        agingShare: Double = 0.75
    ) -> LiveActivityFreshness {
        guard let staleDate else { return .fresh }
        if now >= staleDate { return .stale }
        let window = staleDate.timeIntervalSince(updatedAt)
        guard window > 0 else { return .fresh }
        let elapsed = now.timeIntervalSince(updatedAt)
        let share = agingShare.isNaN ? 0.75 : min(max(agingShare, 0), 1)
        return elapsed / window >= share ? .aging : .fresh
    }
}
