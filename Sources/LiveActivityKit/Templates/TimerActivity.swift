import Foundation
import SwiftUI
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// A countdown timer, such as a cooking timer or a workout interval. It ticks on its own between updates; pausing and
/// resuming are updates.
///
/// ```swift
/// let attributes = TimerActivityAttributes(title: "Pasta", symbolName: "fork.knife")
/// let running = TimerActivityAttributes.ContentState(startDate: .now, endDate: .now + 600, phase: "Boil")
/// let paused = running.paused(at: .now)
/// ```
public struct TimerActivityAttributes: LiveActivityTemplate {
    /// What the timer is for, such as "Pasta".
    public var title: String
    /// The SF Symbol of the timer.
    public var symbolName: String
    /// The accent color.
    public var tint: ActivityTint

    public init(title: String, symbolName: String = "timer", tint: ActivityTint = .yellow) {
        self.title = title
        self.symbolName = symbolName
        self.tint = tint
    }

    public struct ContentState: Codable, Hashable, Sendable {
        /// When the timer started (or would have, counting the paused time out).
        public var startDate: Date
        /// When the timer rings.
        public var endDate: Date
        /// The time left while paused; `nil` while running.
        public var pausedRemaining: TimeInterval?
        /// A step or phase, such as "Boil" or "Round 2 of 8".
        public var phase: String?

        public init(startDate: Date, endDate: Date, pausedRemaining: TimeInterval? = nil, phase: String? = nil) {
            self.startDate = startDate
            self.endDate = endDate
            self.pausedRemaining = pausedRemaining
            self.phase = phase
        }

        /// `true` while paused.
        public var isPaused: Bool {
            pausedRemaining != nil
        }

        /// Where the timer stands at `now`.
        public func progress(at now: Date) -> TimerProgress {
            TimerProgress(start: startDate, end: endDate, pausedRemaining: pausedRemaining, now: now)
        }

        /// The state paused at `now`, keeping the time left. A paused state stays as it is.
        public func paused(at now: Date) -> ContentState {
            guard pausedRemaining == nil else { return self }
            var copy = self
            copy.pausedRemaining = progress(at: now).remaining
            return copy
        }

        /// The state resumed at `now`: the start and end move by the time spent paused. A running state stays as it is.
        public func resumed(at now: Date) -> ContentState {
            guard let pausedRemaining else { return self }
            let progress = TimerProgress(start: startDate, end: endDate, pausedRemaining: pausedRemaining, now: now)
            var copy = self
            copy.endDate = now.addingTimeInterval(progress.remaining)
            copy.startDate = copy.endDate.addingTimeInterval(-progress.duration)
            copy.pausedRemaining = nil
            return copy
        }
    }

    public var accentTint: ActivityTint { tint }

    @MainActor
    public static func makeView(
        attributes: TimerActivityAttributes,
        state: ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool
    ) -> TimerActivityView {
        TimerActivityView(attributes: attributes, state: state, presentation: presentation, isStale: isStale)
    }
}

/// Every presentation of a ``TimerActivityAttributes`` activity.
public struct TimerActivityView: View {
    private let attributes: TimerActivityAttributes
    private let state: TimerActivityAttributes.ContentState
    private let presentation: LiveActivityPresentation
    private let isStale: Bool

    @Environment(\.liveActivityNow) private var fixedNow

    public init(
        attributes: TimerActivityAttributes,
        state: TimerActivityAttributes.ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool = false
    ) {
        self.attributes = attributes
        self.state = state
        self.presentation = presentation
        self.isStale = isStale
    }

    private var tint: Color { attributes.tint.color }

    public var body: some View {
        switch presentation {
        case .lockScreen:
            lockScreen
        case .compactLeading:
            Image(systemName: state.isPaused ? "pause.fill" : attributes.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        case .compactTrailing:
            countdown
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 52, alignment: .trailing)
        case .minimal:
            ring(lineWidth: 3) {
                Image(systemName: state.isPaused ? "pause.fill" : attributes.symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
        case .expandedLeading:
            Label {
                Text(attributes.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: attributes.symbolName)
                    .foregroundStyle(tint)
            }
            .padding(.leading, 4)
        case .expandedTrailing:
            countdown
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110, alignment: .trailing)
                .padding(.trailing, 4)
        case .expandedCenter:
            Text(state.phase ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        case .expandedBottom:
            VStack(spacing: 6) {
                bar
                footer
            }
            .padding(.horizontal, 4)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                LiveActivitySymbolBadge(systemName: attributes.symbolName, tint: attributes.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(attributes.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text(state.isPaused ? "Paused" : (state.phase ?? "Timer"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(state.isPaused ? tint : Color.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                countdown
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            bar
            if isStale {
                LiveActivityStaleNote()
            } else {
                footer
            }
        }
        .foregroundStyle(.white)
    }

    private var countdown: some View {
        LiveActivityCountdown(to: state.endDate, style: .clock, pausedRemaining: state.pausedRemaining)
    }

    /// A static bar in previews or while paused, a live one in a running activity.
    @ViewBuilder
    private var bar: some View {
        if state.isPaused || fixedNow != nil {
            let progress = state.progress(at: fixedNow ?? Date())
            ProgressView(value: progress.fraction)
                .tint(tint)
        } else {
            ProgressView(timerInterval: ETAFormatter.timerRange(from: state.startDate, to: state.endDate), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        }
    }

    @ViewBuilder
    private func ring<Content: View>(lineWidth: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        if state.isPaused || fixedNow != nil {
            LiveActivityRing(fraction: state.progress(at: fixedNow ?? Date()).fraction, tint: tint, lineWidth: lineWidth, content: content)
        } else {
            ProgressView(timerInterval: ETAFormatter.timerRange(from: state.startDate, to: state.endDate), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                content()
            }
            .progressViewStyle(.circular)
            .tint(tint)
        }
    }

    private var footer: some View {
        HStack {
            Text(state.isPaused ? "Paused" : "Ends at")
            if !state.isPaused {
                Text(state.endDate, style: .time)
            }
            Spacer()
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.7))
    }
}

#if canImport(ActivityKit) && os(iOS)
extension TimerActivityAttributes: ActivityAttributes {}
#endif
