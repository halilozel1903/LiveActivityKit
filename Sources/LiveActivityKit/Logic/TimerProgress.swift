import Foundation

/// Where a countdown timer stands at one moment: running, paused or finished.
///
/// ```swift
/// let progress = TimerProgress(start: start, end: start + 600, now: start + 150)
/// progress.remaining     // 450
/// progress.fraction      // 0.25
/// progress.isFinished    // false
///
/// let paused = TimerProgress(start: start, end: start + 600, pausedRemaining: 200, now: .now)
/// paused.remaining       // 200, whatever the time
/// ```
///
/// A timer whose end is before its start has a duration of zero and is finished; a paused remaining time is clamped to
/// the duration, so a bad push never shows more time than the timer had.
public struct TimerProgress: Hashable, Sendable {
    /// The whole length of the timer, in seconds, never negative.
    public let duration: TimeInterval
    /// The time left, in seconds, from 0 to ``duration``.
    public let remaining: TimeInterval
    /// `true` while the timer is paused.
    public let isPaused: Bool

    public init(start: Date, end: Date, pausedRemaining: TimeInterval? = nil, now: Date) {
        let duration = max(0, end.timeIntervalSince(start))
        self.duration = duration
        if let pausedRemaining {
            isPaused = true
            remaining = pausedRemaining.isNaN ? duration : min(max(0, pausedRemaining), duration)
        } else {
            isPaused = false
            remaining = min(max(0, end.timeIntervalSince(now)), duration)
        }
    }

    /// The time already gone, in seconds.
    public var elapsed: TimeInterval {
        duration - remaining
    }

    /// How much of the timer has run, from 0 to 1. A timer without a duration is complete.
    public var fraction: Double {
        guard duration > 0 else { return 1 }
        return elapsed / duration
    }

    /// `true` once a running timer reached its end. A paused timer is never finished.
    public var isFinished: Bool {
        !isPaused && remaining == 0
    }

    /// The end date to show for a paused timer if it were resumed at `now`.
    public func resumedEnd(at now: Date) -> Date {
        now.addingTimeInterval(remaining)
    }
}
