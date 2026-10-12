import Foundation
import Testing
@testable import LiveActivityKit

/// A fixed moment for every test: Thursday, October 8, 2026, 18:20 UTC.
let referenceDate = Date(timeIntervalSince1970: 1_791_484_800)

@Suite("Step progress")
struct StepProgressTests {
    @Test func middleStep() {
        let progress = StepProgress(count: 4, currentIndex: 2)
        let expected: [StepState] = [.completed, .completed, .current, .upcoming]

        #expect(progress.states == expected)
        #expect(abs(progress.fraction - 2.0 / 3.0) < 1e-12)
        #expect(!progress.isComplete)
        #expect(progress.remainingSteps == 1)
        #expect(progress.completedCount == 2)
        #expect(progress.state(at: -1) == .completed)
        #expect(progress.state(at: 9) == .upcoming)
    }

    @Test func lastStepCompletesTheList() {
        let progress = StepProgress(count: 4, currentIndex: 3)
        let expected: [StepState] = [.completed, .completed, .completed, .completed]

        #expect(progress.isComplete)
        #expect(progress.states == expected)
        #expect(progress.fraction == 1)
        #expect(progress.remainingSteps == 0)
    }

    @Test func outOfRangeIndicesAreClamped() {
        #expect(StepProgress(count: 4, currentIndex: 9).currentIndex == 3)
        #expect(StepProgress(count: 4, currentIndex: -2).currentIndex == 0)
        #expect(StepProgress(count: -1, currentIndex: 2).count == 0)
        #expect(StepProgress(count: 4, currentIndex: 1).advanced(by: 5).currentIndex == 3)
        #expect(StepProgress(count: 4, currentIndex: 2).advanced(by: -1).currentIndex == 1)
    }

    @Test func emptyAndSingleLists() {
        let empty = StepProgress(count: 0, currentIndex: 0)
        #expect(empty.states.isEmpty)
        #expect(empty.fraction == 0)
        #expect(!empty.isComplete)
        #expect(empty.remainingSteps == 0)

        let single = StepProgress(count: 1, currentIndex: 0)
        #expect(single.isComplete)
        #expect(single.fraction == 1)
    }
}

@Suite("ETA formatting")
struct ETAFormatterTests {
    @Test func minutesRoundUp() {
        #expect(ETAFormatter.minutesRemaining(until: referenceDate.addingTimeInterval(30), from: referenceDate) == 1)
        #expect(ETAFormatter.minutesRemaining(until: referenceDate.addingTimeInterval(1_260), from: referenceDate) == 21)
        #expect(ETAFormatter.minutesRemaining(until: referenceDate.addingTimeInterval(1_261), from: referenceDate) == 22)
        #expect(ETAFormatter.minutesRemaining(until: referenceDate.addingTimeInterval(-60), from: referenceDate) == 0)
    }

    @Test func compactText() {
        #expect(ETAFormatter.compact(minutes: 0) == "Now")
        #expect(ETAFormatter.compact(minutes: -5) == "Now")
        #expect(ETAFormatter.compact(minutes: 1) == "1 min")
        #expect(ETAFormatter.compact(minutes: 59) == "59 min")
        #expect(ETAFormatter.compact(minutes: 60) == "1 h")
        #expect(ETAFormatter.compact(minutes: 65) == "1 h 5 min")
        #expect(ETAFormatter.compact(until: referenceDate.addingTimeInterval(1_260), from: referenceDate) == "21 min")
        #expect(ETAFormatter.arrival(until: referenceDate.addingTimeInterval(1_260), from: referenceDate) == "Arriving in 21 min")
        #expect(ETAFormatter.arrival(until: referenceDate, from: referenceDate) == "Arriving now")
    }

    @Test func lateness() {
        #expect(ETAFormatter.minutesLate(eta: referenceDate, now: referenceDate.addingTimeInterval(100)) == 0)
        #expect(ETAFormatter.minutesLate(eta: referenceDate, now: referenceDate.addingTimeInterval(200)) == 2)
        #expect(ETAFormatter.minutesLate(eta: referenceDate, now: referenceDate.addingTimeInterval(200), grace: 0) == 4)
        #expect(ETAFormatter.minutesLate(eta: referenceDate, now: referenceDate.addingTimeInterval(-600)) == 0)
    }

    @Test func countdownClock() {
        #expect(ETAFormatter.countdown(45) == "0:45")
        #expect(ETAFormatter.countdown(754) == "12:34")
        #expect(ETAFormatter.countdown(3_723) == "1:02:03")
        #expect(ETAFormatter.countdown(0.2) == "0:01")
        #expect(ETAFormatter.countdown(-5) == "0:00")
        #expect(ETAFormatter.countdown(.nan) == "--:--")
    }

    @Test func distances() {
        #expect(ETAFormatter.distance(meters: 449) == "450 m")
        #expect(ETAFormatter.distance(meters: 0) == "0 m")
        #expect(ETAFormatter.distance(meters: 995) == "1 km")
        #expect(ETAFormatter.distance(meters: 1_234) == "1.2 km")
        #expect(ETAFormatter.distance(meters: 12_345) == "12 km")
        #expect(ETAFormatter.distance(meters: -20) == "0 m")
        #expect(ETAFormatter.distance(meters: .infinity) == "--")
    }

    @Test func timerRanges() {
        let later = referenceDate.addingTimeInterval(60)
        #expect(ETAFormatter.timerRange(from: referenceDate, to: later) == referenceDate...later)
        #expect(ETAFormatter.timerRange(from: later, to: referenceDate) == referenceDate...referenceDate)
    }
}

@Suite("Staleness")
struct StalenessTests {
    @Test func staleDates() {
        #expect(LiveActivityStaleness.staleDate(updatedAt: referenceDate, maxAge: 600) == referenceDate.addingTimeInterval(600))
        #expect(LiveActivityStaleness.staleDate(updatedAt: referenceDate, maxAge: -5) == referenceDate)
        #expect(LiveActivityStaleness.staleDate(updatedAt: referenceDate, maxAge: .nan) == referenceDate)

        // The ETA plus grace comes before the maximum age.
        let byETA = LiveActivityStaleness.staleDate(
            eta: referenceDate.addingTimeInterval(300), updatedAt: referenceDate, grace: 600, maxAge: 1_800
        )
        #expect(byETA == referenceDate.addingTimeInterval(900))
        // The maximum age comes first.
        let byAge = LiveActivityStaleness.staleDate(
            eta: referenceDate.addingTimeInterval(7_200), updatedAt: referenceDate, grace: 600, maxAge: 1_800
        )
        #expect(byAge == referenceDate.addingTimeInterval(1_800))
        let withoutETA = LiveActivityStaleness.staleDate(eta: nil, updatedAt: referenceDate, grace: 600, maxAge: 60)
        #expect(withoutETA == referenceDate.addingTimeInterval(60))
    }

    @Test func freshness() {
        let stale = referenceDate.addingTimeInterval(100)
        #expect(LiveActivityStaleness.isStale(staleDate: nil, now: referenceDate) == false)
        #expect(LiveActivityStaleness.isStale(staleDate: stale, now: stale))
        #expect(LiveActivityStaleness.freshness(updatedAt: referenceDate, staleDate: stale, now: referenceDate.addingTimeInterval(50)) == .fresh)
        #expect(LiveActivityStaleness.freshness(updatedAt: referenceDate, staleDate: stale, now: referenceDate.addingTimeInterval(80)) == .aging)
        #expect(LiveActivityStaleness.freshness(updatedAt: referenceDate, staleDate: stale, now: stale) == .stale)
        #expect(LiveActivityStaleness.freshness(updatedAt: referenceDate, staleDate: nil, now: stale) == .fresh)
        #expect(LiveActivityStaleness.freshness(updatedAt: stale, staleDate: referenceDate.addingTimeInterval(50), now: referenceDate) == .fresh)
    }
}

private struct SampleState: Codable, Hashable {
    var count: Int
    var note: String?
    var items: [Int]
}

@Suite("Content state diffs")
struct ContentStateDiffTests {
    @Test func changedKeys() {
        let old = SampleState(count: 1, note: "a", items: [1])
        let new = SampleState(count: 2, note: "a", items: [1, 2])

        #expect(ContentStateDiff.changedKeys(from: old, to: new) == ["count", "items"])
        #expect(ContentStateDiff.changedKeys(from: old, to: old).isEmpty)
        #expect(ContentStateDiff.hasChanges(from: old, to: new))
        #expect(!ContentStateDiff.hasChanges(from: old, to: new, ignoring: ["count", "items"]))
    }

    @Test func missingAndNullAreTheSame() {
        let withoutNote = SampleState(count: 1, note: nil, items: [])
        let withNote = SampleState(count: 1, note: "late", items: [])

        #expect(ContentStateDiff.changedKeys(from: withoutNote, to: withNote) == ["note"])
        #expect(ContentStateDiff.changedKeys(from: withoutNote, to: withoutNote).isEmpty)
    }

    @Test func valuesThatAreNotObjects() {
        #expect(ContentStateDiff.changedKeys(from: StepState.current, to: StepState.completed) == [ContentStateDiff.wholeValueKey])
        #expect(ContentStateDiff.changedKeys(from: StepState.current, to: StepState.current).isEmpty)
    }
}

@Suite("Timers")
struct TimerProgressTests {
    @Test func running() {
        let end = referenceDate.addingTimeInterval(600)
        let progress = TimerProgress(start: referenceDate, end: end, now: referenceDate.addingTimeInterval(150))

        #expect(progress.duration == 600)
        #expect(progress.remaining == 450)
        #expect(progress.elapsed == 150)
        #expect(progress.fraction == 0.25)
        #expect(!progress.isPaused)
        #expect(!progress.isFinished)
    }

    @Test func finished() {
        let progress = TimerProgress(start: referenceDate, end: referenceDate.addingTimeInterval(600), now: referenceDate.addingTimeInterval(700))
        #expect(progress.remaining == 0)
        #expect(progress.fraction == 1)
        #expect(progress.isFinished)

        let backwards = TimerProgress(start: referenceDate, end: referenceDate.addingTimeInterval(-10), now: referenceDate)
        #expect(backwards.duration == 0)
        #expect(backwards.fraction == 1)
        #expect(backwards.isFinished)
    }

    @Test func paused() {
        let end = referenceDate.addingTimeInterval(600)
        let paused = TimerProgress(start: referenceDate, end: end, pausedRemaining: 200, now: referenceDate.addingTimeInterval(5_000))
        #expect(paused.isPaused)
        #expect(paused.remaining == 200)
        #expect(!paused.isFinished)
        #expect(paused.resumedEnd(at: referenceDate) == referenceDate.addingTimeInterval(200))

        let clamped = TimerProgress(start: referenceDate, end: end, pausedRemaining: 900, now: referenceDate)
        #expect(clamped.remaining == 600)
        let negative = TimerProgress(start: referenceDate, end: end, pausedRemaining: -1, now: referenceDate)
        #expect(negative.remaining == 0)
    }
}

@Suite("Scores and rides")
struct ScoreAndRideTests {
    @Test func scoreLine() {
        let line = ScoreLine(home: 98, away: 95)
        #expect(line.leader == .home)
        #expect(line.margin == 3)
        #expect(!line.isTied)
        #expect(line.score(of: .away) == 95)
        #expect(line.text(home: "HAW", away: "FOX") == "HAW 98 \u{2013} 95 FOX")
        #expect(ScoreLine(home: 2, away: 2).leader == nil)
        #expect(ScoreLine(home: -3, away: 1).home == 0)
        #expect(ScoreSide.home.opponent == .away)
    }

    @Test func scoringSide() {
        let before = ScoreLine(home: 98, away: 95)
        #expect(ScoreLine.scoringSide(from: before, to: ScoreLine(home: 100, away: 95)) == .home)
        #expect(ScoreLine.scoringSide(from: before, to: ScoreLine(home: 98, away: 98)) == .away)
        #expect(ScoreLine.scoringSide(from: before, to: before) == nil)
        #expect(ScoreLine.scoringSide(from: before, to: ScoreLine(home: 100, away: 97)) == nil)
        #expect(ScoreLine.scoringSide(from: before, to: ScoreLine(home: 97, away: 95)) == nil)
    }

    @Test func rideProgress() {
        let progress = RideProgress(remaining: 1_200, total: 4_800)
        #expect(progress.fraction == 0.75)
        #expect(progress.distanceText == "1.2 km")
        #expect(RideProgress(remaining: 100, total: 0).fraction == 1)
        #expect(RideProgress(remaining: 9_000, total: 4_800).remaining == 4_800)
        #expect(RideProgress(remaining: .nan, total: 4_800).fraction == 0)
        #expect(RideProgress(remaining: -5, total: 4_800).fraction == 1)
    }

    @Test func ridePhases() {
        #expect(RidePhase.driverEnRoute.title == "Driver on the way")
        #expect(!RidePhase.arriving.isRiding)
        #expect(RidePhase.onTrip.isRiding)
        #expect(RidePhase.arrived.isFinished)
        #expect(RidePhase.allCases.filter(\.isRiding).count == 2)
    }
}

@Suite("Tints and push tokens")
struct TintAndTokenTests {
    @Test func hexColors() throws {
        let tint = try #require(ActivityTint(hex: "#FF6B00"))
        #expect(tint.hex == "#FF6B00")
        #expect(tint == ActivityTint.orange)
        #expect(ActivityTint(hex: "ff6b00")?.hex == "#FF6B00")
        #expect(ActivityTint(hex: " #f60 ")?.hex == "#FF6600")
        #expect(ActivityTint(hex: "#GG0000") == nil)
        #expect(ActivityTint(hex: "#12345") == nil)
        #expect(ActivityTint(hex: "") == nil)
        #expect(ActivityTint(red: 2, green: -1, blue: .nan).hex == "#FF0000")
    }

    @Test func contrast() {
        let white = ActivityTint(red: 1, green: 1, blue: 1)
        let black = ActivityTint(red: 0, green: 0, blue: 0)
        #expect(abs(white.luminance - 1) < 1e-9)
        #expect(black.luminance == 0)
        #expect(white.prefersDarkContent)
        #expect(!black.prefersDarkContent)
        #expect(ActivityTint.yellow.prefersDarkContent)
        #expect(ActivityTint(hex: "#552583")?.prefersDarkContent == false)
    }

    @Test func tintsTravelAsHexStrings() throws {
        let data = try JSONEncoder().encode([ActivityTint.orange])
        #expect(String(decoding: data, as: UTF8.self) == "[\"#FF6B00\"]")
        let decoded = try JSONDecoder().decode([ActivityTint].self, from: data)
        #expect(decoded == [ActivityTint.orange])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([ActivityTint].self, from: Data("[\"orange\"]".utf8))
        }
    }

    @Test func pushTokens() {
        let token = Data([0x8F, 0x3A, 0x00, 0xFF])
        #expect(PushToken.hexString(token) == "8f3a00ff")
        #expect(PushToken.hexString(Data()) == "")
        #expect(PushToken.data(fromHex: "8F3A00ff") == token)
        #expect(PushToken.data(fromHex: "8f3") == nil)
        #expect(PushToken.data(fromHex: "zz") == nil)
        #expect(PushToken.data(fromHex: "") == Data())
    }
}

@Suite("Update policy")
struct UpdatePolicyTests {
    @Test func unchangedUpdatesAreSkipped() {
        let policy = LiveActivityUpdatePolicy(ignoredKeys: ["note"])
        let old = SampleState(count: 1, note: "a", items: [])

        #expect(policy.decision(from: old, to: old, lastUpdate: referenceDate, now: referenceDate) == .unchanged)
        #expect(policy.decision(from: old, to: SampleState(count: 1, note: "b", items: []), lastUpdate: nil, now: referenceDate) == .unchanged)
        #expect(policy.decision(from: old, to: SampleState(count: 2, note: "a", items: []), lastUpdate: nil, now: referenceDate) == .send)
        #expect(policy.decision(from: nil, to: old, lastUpdate: nil, now: referenceDate) == .send)
    }

    @Test func throttling() {
        let policy = LiveActivityUpdatePolicy(minimumInterval: 10)
        let old = SampleState(count: 1, note: nil, items: [])
        let new = SampleState(count: 2, note: nil, items: [])
        let soon = referenceDate.addingTimeInterval(5)

        #expect(policy.decision(from: old, to: new, lastUpdate: referenceDate, now: soon) == .throttled)
        #expect(policy.decision(from: old, to: new, lastUpdate: referenceDate, now: referenceDate.addingTimeInterval(10)) == .send)
        #expect(policy.decision(from: old, to: new, lastUpdate: referenceDate, now: soon, hasAlert: true) == .send)
        #expect(policy.decision(from: old, to: old, lastUpdate: referenceDate, now: soon, force: true) == .send)
    }

    @Test func staleDates() {
        let policy = LiveActivityUpdatePolicy(maxAge: 300)
        let explicit = referenceDate.addingTimeInterval(42)
        #expect(policy.staleDate(explicit: explicit, now: referenceDate) == explicit)
        #expect(policy.staleDate(explicit: nil, now: referenceDate) == referenceDate.addingTimeInterval(300))
        #expect(LiveActivityUpdatePolicy(maxAge: nil).staleDate(explicit: nil, now: referenceDate) == nil)
    }
}
