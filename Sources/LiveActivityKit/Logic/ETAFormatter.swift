import Foundation

/// Short, locale-independent arrival times, countdowns and distances for the few points a Live Activity has.
///
/// ```swift
/// ETAFormatter.compact(until: eta, from: now)     // "Now", "1 min", "21 min", "1 h 5 min"
/// ETAFormatter.arrival(until: eta, from: now)     // "Arriving in 21 min"
/// ETAFormatter.countdown(334)                     // "5:34"
/// ETAFormatter.distance(meters: 1_234)            // "1.2 km"
/// ```
public enum ETAFormatter {
    /// Whole minutes until `eta`, rounded up so "less than a minute" still reads "1 min". Zero once `eta` is reached.
    public static func minutesRemaining(until eta: Date, from now: Date) -> Int {
        let seconds = eta.timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        // A day is far more than any Live Activity lasts (they end after 8 hours), so the clamp only guards the Int.
        return Int((min(seconds, 1_000_000) / 60).rounded(.up))
    }

    /// "Now", "1 min", "21 min", "1 h", "1 h 5 min".
    public static func compact(minutes: Int) -> String {
        let minutes = max(0, minutes)
        switch minutes {
        case 0:
            return "Now"
        case ..<60:
            return "\(minutes) min"
        default:
            let hours = minutes / 60
            let rest = minutes % 60
            return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
        }
    }

    /// The time left until `eta` as `compact(minutes:)` text.
    public static func compact(until eta: Date, from now: Date) -> String {
        compact(minutes: minutesRemaining(until: eta, from: now))
    }

    /// "Arriving in 21 min", or "Arriving now" once `eta` is reached.
    public static func arrival(until eta: Date, from now: Date) -> String {
        let minutes = minutesRemaining(until: eta, from: now)
        return minutes == 0 ? "Arriving now" : "Arriving in \(compact(minutes: minutes))"
    }

    /// Whole minutes past `eta`, ignoring the first `grace` seconds. Zero while on time.
    public static func minutesLate(eta: Date, now: Date, grace: TimeInterval = 120) -> Int {
        let late = now.timeIntervalSince(eta) - max(0, grace)
        guard late > 0 else { return 0 }
        return Int((min(late, 1_000_000) / 60).rounded(.up))
    }

    /// A countdown clock: "0:45", "12:34", "1:02:03". Seconds round up, like a kitchen timer that shows 0:01 until
    /// it is really done. Negative durations read "0:00" and NaN "--:--".
    public static func countdown(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN else { return "--:--" }
        let total = Int(min(max(seconds, 0), 359_999).rounded(.up))
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// "450 m" (rounded to 10 m), "1.2 km" below 10 km, "12 km" above. Always metric with a "." separator.
    public static func distance(meters: Double) -> String {
        guard meters.isFinite else { return "--" }
        let meters = max(0, meters)
        let rounded = (meters / 10).rounded() * 10
        if rounded < 1_000 {
            return "\(Int(rounded)) m"
        }
        let kilometers = meters / 1_000
        if kilometers < 9.95 {
            var text = String(format: "%.1f", kilometers)
            if text.hasSuffix(".0") { text.removeLast(2) }
            return text + " km"
        }
        return "\(Int(kilometers.rounded())) km"
    }

    /// A range for `Text(timerInterval:)` and `ProgressView(timerInterval:)`, which trap on a reversed range. When
    /// `end` is before `start` the range is empty at `end`, so the timer reads zero.
    public static func timerRange(from start: Date, to end: Date) -> ClosedRange<Date> {
        start <= end ? start...end : end...end
    }
}
