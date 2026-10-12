import Foundation

/// A side of a match.
public enum ScoreSide: String, Codable, Hashable, Sendable, CaseIterable {
    case home
    case away

    /// The other side.
    public var opponent: ScoreSide {
        self == .home ? .away : .home
    }
}

/// The score of a match and what can be read from it: who leads, by how much, and who just scored.
///
/// ```swift
/// let line = ScoreLine(home: 98, away: 95)
/// line.leader                                 // .home
/// line.margin                                 // 3
/// line.text(home: "LAL", away: "BOS")         // "LAL 98 – 95 BOS"
/// ScoreLine.scoringSide(from: ScoreLine(home: 98, away: 95), to: line)   // nil, nothing changed
/// ```
public struct ScoreLine: Hashable, Sendable {
    /// The home score, never negative.
    public let home: Int
    /// The away score, never negative.
    public let away: Int

    public init(home: Int, away: Int) {
        self.home = max(0, home)
        self.away = max(0, away)
    }

    /// The score of `side`.
    public func score(of side: ScoreSide) -> Int {
        side == .home ? home : away
    }

    /// The side ahead, or `nil` for a tie.
    public var leader: ScoreSide? {
        if home == away { return nil }
        return home > away ? .home : .away
    }

    /// The difference between the scores.
    public var margin: Int {
        abs(home - away)
    }

    /// `true` when the scores are level.
    public var isTied: Bool {
        home == away
    }

    /// "LAL 98 – 95 BOS", with an en dash.
    public func text(home homeName: String, away awayName: String) -> String {
        "\(homeName) \(home) \u{2013} \(away) \(awayName)"
    }

    /// The side whose score went up between two updates, or `nil` when neither or both changed (a correction or a
    /// missed update). Use it to decide whether an update deserves an alert.
    public static func scoringSide(from old: ScoreLine, to new: ScoreLine) -> ScoreSide? {
        let homeScored = new.home > old.home
        let awayScored = new.away > old.away
        switch (homeScored, awayScored) {
        case (true, false): return .home
        case (false, true): return .away
        default: return nil
        }
    }
}
