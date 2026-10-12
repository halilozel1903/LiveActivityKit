import Foundation
import SwiftUI
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// A live match: two teams, the score, the period and its clock, and the last play.
///
/// ```swift
/// let attributes = ScoreActivityAttributes(
///     league: "Pro Basketball",
///     home: .init(name: "Harbor Hawks", abbreviation: "HAW", tint: ActivityTint(hex: "#0B6EF5")!),
///     away: .init(name: "Desert Foxes", abbreviation: "FOX", tint: ActivityTint(hex: "#F2552C")!)
/// )
/// let state = ScoreActivityAttributes.ContentState(homeScore: 98, awayScore: 95, period: "Q4", clockEnd: .now + 252)
/// ```
public struct ScoreActivityAttributes: LiveActivityTemplate {
    /// A team.
    public struct Team: Codable, Hashable, Sendable {
        public var name: String
        /// Two to four letters for the compact island, such as "HAW".
        public var abbreviation: String
        public var tint: ActivityTint

        public init(name: String, abbreviation: String, tint: ActivityTint) {
            self.name = name
            self.abbreviation = abbreviation
            self.tint = tint
        }
    }

    /// The competition, such as "Pro Basketball" or "Premier League".
    public var league: String
    public var home: Team
    public var away: Team

    public init(league: String, home: Team, away: Team) {
        self.league = league
        self.home = home
        self.away = away
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public var homeScore: Int
        public var awayScore: Int
        /// The period, such as "Q4", "2nd half" or "Final".
        public var period: String
        /// When the running clock of the period reaches zero; it then counts down on its own. `nil` when stopped.
        public var clockEnd: Date?
        /// The clock to show while it is stopped, such as "4:12" or "HT".
        public var clockText: String?
        /// The last play, such as "3-pt jumper by #23".
        public var lastPlay: String?
        /// The side with the ball, when the sport has one.
        public var possession: ScoreSide?
        /// `true` once the match is over.
        public var isFinal: Bool

        public init(
            homeScore: Int,
            awayScore: Int,
            period: String,
            clockEnd: Date? = nil,
            clockText: String? = nil,
            lastPlay: String? = nil,
            possession: ScoreSide? = nil,
            isFinal: Bool = false
        ) {
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.period = period
            self.clockEnd = clockEnd
            self.clockText = clockText
            self.lastPlay = lastPlay
            self.possession = possession
            self.isFinal = isFinal
        }

        /// The score as a ``ScoreLine``.
        public var line: ScoreLine {
            ScoreLine(home: homeScore, away: awayScore)
        }
    }

    /// The team on `side`.
    public func team(_ side: ScoreSide) -> Team {
        side == .home ? home : away
    }

    /// An alert for an update that changed the score, such as "HAW 100 – 95 FOX", or `nil` when nobody scored.
    public func scoreAlert(from old: ContentState, to new: ContentState) -> LiveActivityAlert? {
        guard let side = ScoreLine.scoringSide(from: old.line, to: new.line) else { return nil }
        return LiveActivityAlert(
            title: team(side).name + " score",
            body: new.line.text(home: home.abbreviation, away: away.abbreviation)
        )
    }

    public var accentTint: ActivityTint { home.tint }

    @MainActor
    public static func makeView(
        attributes: ScoreActivityAttributes,
        state: ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool
    ) -> ScoreActivityView {
        ScoreActivityView(attributes: attributes, state: state, presentation: presentation, isStale: isStale)
    }
}

/// Every presentation of a ``ScoreActivityAttributes`` activity.
public struct ScoreActivityView: View {
    private let attributes: ScoreActivityAttributes
    private let state: ScoreActivityAttributes.ContentState
    private let presentation: LiveActivityPresentation
    private let isStale: Bool

    public init(
        attributes: ScoreActivityAttributes,
        state: ScoreActivityAttributes.ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool = false
    ) {
        self.attributes = attributes
        self.state = state
        self.presentation = presentation
        self.isStale = isStale
    }

    public var body: some View {
        switch presentation {
        case .lockScreen:
            lockScreen
        case .compactLeading:
            compactScore(.home)
        case .compactTrailing:
            compactScore(.away)
        case .minimal:
            Text("\(state.homeScore)-\(state.awayScore)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        case .expandedLeading:
            expandedTeam(.home)
        case .expandedTrailing:
            expandedTeam(.away)
        case .expandedCenter:
            VStack(spacing: 2) {
                Text("\(state.homeScore) \u{2013} \(state.awayScore)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                periodLine
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        case .expandedBottom:
            Group {
                if isStale {
                    LiveActivityStaleNote()
                } else if let lastPlay = state.lastPlay {
                    Text(lastPlay)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 10) {
            HStack {
                Text(attributes.league.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                Spacer()
                periodLine
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state.isFinal ? Color.white.opacity(0.65) : Color.red)
            }
            HStack(alignment: .center, spacing: 10) {
                teamColumn(.home)
                Text("\(state.homeScore)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .opacity(state.line.leader == .away ? 0.6 : 1)
                    .frame(minWidth: 56, alignment: .trailing)
                Text("\u{2013}")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(state.awayScore)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .opacity(state.line.leader == .home ? 0.6 : 1)
                    .frame(minWidth: 56, alignment: .leading)
                teamColumn(.away)
            }
            if isStale {
                LiveActivityStaleNote()
            } else if let lastPlay = state.lastPlay {
                Text(lastPlay)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
    }

    private func teamColumn(_ side: ScoreSide) -> some View {
        let team = attributes.team(side)
        return VStack(spacing: 4) {
            ScoreTeamBadge(team: team, size: 36)
                .overlay(alignment: side == .home ? .topTrailing : .topLeading) {
                    if state.possession == side && !state.isFinal {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .offset(x: side == .home ? 4 : -4, y: -2)
                    }
                }
            Text(team.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactScore(_ side: ScoreSide) -> some View {
        let team = attributes.team(side)
        let score = side == .home ? state.homeScore : state.awayScore
        return HStack(spacing: 4) {
            if side == .away {
                Text("\(score)")
                    .monospacedDigit()
            }
            Text(team.abbreviation)
                .foregroundStyle(team.tint.color)
            if side == .home {
                Text("\(score)")
                    .monospacedDigit()
            }
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func expandedTeam(_ side: ScoreSide) -> some View {
        let team = attributes.team(side)
        return VStack(spacing: 4) {
            ScoreTeamBadge(team: team, size: 34)
            Text(team.abbreviation)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var periodLine: some View {
        if state.isFinal {
            Text("Final")
        } else if let clockEnd = state.clockEnd {
            HStack(spacing: 4) {
                Text(state.period)
                LiveActivityCountdown(to: clockEnd, style: .clock)
                    .frame(maxWidth: 52, alignment: .leading)
            }
        } else if let clockText = state.clockText {
            Text(state.period + " " + clockText)
        } else {
            Text(state.period)
        }
    }
}

/// A team's abbreviation on a circle of its color.
public struct ScoreTeamBadge: View {
    private let team: ScoreActivityAttributes.Team
    private let size: CGFloat

    public init(team: ScoreActivityAttributes.Team, size: CGFloat = 36) {
        self.team = team
        self.size = size
    }

    public var body: some View {
        Text(team.abbreviation.prefix(3))
            .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
            .foregroundStyle(team.tint.contentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: size, height: size)
            .background(team.tint.color, in: Circle())
    }
}

#if canImport(ActivityKit) && os(iOS)
extension ScoreActivityAttributes: ActivityAttributes {}
#endif
