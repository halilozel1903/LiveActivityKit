import Foundation
import SwiftUI

// MARK: - A fixed "now" for previews

private struct LiveActivityNowKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    /// A fixed time the templates draw at, instead of live timers. `nil` (the default) in a real Live Activity, where
    /// countdowns tick on their own; set it in previews, galleries and screenshots so every frame is the same.
    public var liveActivityNow: Date? {
        get { self[LiveActivityNowKey.self] }
        set { self[LiveActivityNowKey.self] = newValue }
    }
}

extension View {
    /// Draws the templates inside as at `date`, with static text instead of live timers.
    public func liveActivityNow(_ date: Date?) -> some View {
        environment(\.liveActivityNow, date)
    }
}

extension ActivityTint {
    /// The tint as a SwiftUI color.
    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// Black or white, whichever reads better on the tint.
    public var contentColor: Color {
        prefersDarkContent ? .black : .white
    }
}

// MARK: - Countdown

/// A countdown to `end`: live with `Text(timerInterval:)` in a real activity, static text when a
/// ``SwiftUI/EnvironmentValues/liveActivityNow`` is set or the timer is paused.
public struct LiveActivityCountdown: View {
    /// How the static text reads.
    public enum Style: Sendable {
        /// "21 min", for arrival times.
        case minutes
        /// "4:59", for timers.
        case clock
    }

    private let end: Date
    private let style: Style
    private let pausedRemaining: TimeInterval?

    @Environment(\.liveActivityNow) private var fixedNow

    public init(to end: Date, style: Style = .clock, pausedRemaining: TimeInterval? = nil) {
        self.end = end
        self.style = style
        self.pausedRemaining = pausedRemaining
    }

    public var body: some View {
        if let pausedRemaining {
            Text(ETAFormatter.countdown(pausedRemaining))
                .monospacedDigit()
        } else if let fixedNow {
            switch style {
            case .minutes:
                Text(ETAFormatter.compact(until: end, from: fixedNow))
            case .clock:
                Text(ETAFormatter.countdown(end.timeIntervalSince(fixedNow)))
                    .monospacedDigit()
            }
        } else {
            Text(timerInterval: ETAFormatter.timerRange(from: Date(), to: end), countsDown: true, showsHours: false)
                .monospacedDigit()
        }
    }
}

// MARK: - Shapes

/// A progress ring with content in the middle, for the minimal presentation.
public struct LiveActivityRing<Content: View>: View {
    private let fraction: Double
    private let tint: Color
    private let lineWidth: CGFloat
    private let content: Content

    public init(fraction: Double, tint: Color, lineWidth: CGFloat = 3, @ViewBuilder content: () -> Content) {
        self.fraction = fraction.isNaN ? 0 : min(max(fraction, 0), 1)
        self.tint = tint
        self.lineWidth = lineWidth
        self.content = content()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content
        }
        .padding(lineWidth / 2)
    }
}

/// Dots joined by lines for the steps of a ``StepProgress``, with optional titles below.
public struct LiveActivityStepBar: View {
    private let progress: StepProgress
    private let titles: [String]
    private let tint: Color

    public init(progress: StepProgress, titles: [String] = [], tint: Color) {
        self.progress = progress
        self.titles = titles
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<progress.count, id: \.self) { index in
                    if index > 0 {
                        Capsule()
                            .fill(progress.state(at: index) == .upcoming ? Color.white.opacity(0.25) : tint)
                            .frame(height: 3)
                    }
                    dot(for: progress.state(at: index))
                }
            }
            if !titles.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(titles.prefix(progress.count).enumerated()), id: \.offset) { index, title in
                        Text(title)
                            .font(.system(size: 11, weight: index == progress.currentIndex ? .bold : .medium))
                            .foregroundStyle(index == progress.currentIndex ? Color.white : Color.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: alignment(for: index))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func dot(for state: StepState) -> some View {
        switch state {
        case .completed:
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
        case .current:
            Circle()
                .fill(tint)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
        case .upcoming:
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 10, height: 10)
        }
    }

    private func alignment(for index: Int) -> Alignment {
        if index == 0 { return .leading }
        if index == progress.count - 1 { return .trailing }
        return .center
    }

    private var accessibilityText: String {
        guard progress.count > 0 else { return "" }
        let current = titles.indices.contains(progress.currentIndex) ? titles[progress.currentIndex] : ""
        return "Step \(progress.currentIndex + 1) of \(progress.count). \(current)"
    }
}

/// A line that tells the content is out of date: shown when ActivityKit marks the activity stale.
public struct LiveActivityStaleNote: View {
    private let text: String

    public init(_ text: String = "Waiting for an update") {
        self.text = text
    }

    public var body: some View {
        Label(text, systemImage: "exclamationmark.arrow.circlepath")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.yellow)
            .lineLimit(1)
    }
}

/// A round badge with a symbol on a tinted circle, for the leading edge of a Lock Screen view.
public struct LiveActivitySymbolBadge: View {
    private let systemName: String
    private let tint: ActivityTint
    private let size: CGFloat

    public init(systemName: String, tint: ActivityTint, size: CGFloat = 40) {
        self.systemName = systemName
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint.contentColor)
            .frame(width: size, height: size)
            .background(tint.color, in: Circle())
    }
}
