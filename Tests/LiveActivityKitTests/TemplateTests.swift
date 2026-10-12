import Foundation
import Testing
@testable import LiveActivityKit

@Suite("Templates")
struct TemplateTests {
    let delivery = DeliveryActivityAttributes(merchant: "Napoli Pizza", orderNumber: "4821")

    @Test func deliverySteps() {
        let state = DeliveryActivityAttributes.ContentState(stepIndex: 2, eta: referenceDate.addingTimeInterval(1_260))

        #expect(delivery.steps == DeliveryActivityAttributes.defaultSteps)
        #expect(delivery.stepTitle(for: state) == "On the way")
        #expect(delivery.progress(for: state).currentIndex == 2)
        let beyond = DeliveryActivityAttributes.ContentState(stepIndex: 10, eta: referenceDate)
        #expect(delivery.stepTitle(for: beyond) == "Delivered")
        #expect(delivery.progress(for: beyond).isComplete)

        let noSteps = DeliveryActivityAttributes(merchant: "Shop", orderNumber: "1", steps: [])
        #expect(noSteps.stepTitle(for: state).isEmpty)
    }

    @Test func deliveryStaleDate() {
        let state = DeliveryActivityAttributes.ContentState(stepIndex: 2, eta: referenceDate.addingTimeInterval(1_260))
        // Thirty minutes of age come before the ETA plus ten minutes.
        #expect(delivery.staleDate(for: state, updatedAt: referenceDate) == referenceDate.addingTimeInterval(1_800))
        // A near ETA wins.
        let soon = DeliveryActivityAttributes.ContentState(stepIndex: 2, eta: referenceDate.addingTimeInterval(120))
        #expect(delivery.staleDate(for: soon, updatedAt: referenceDate) == referenceDate.addingTimeInterval(720))
    }

    @Test func timerPauseAndResume() {
        let running = TimerActivityAttributes.ContentState(
            startDate: referenceDate,
            endDate: referenceDate.addingTimeInterval(600),
            phase: "Boil"
        )
        #expect(!running.isPaused)
        #expect(running.progress(at: referenceDate.addingTimeInterval(60)).remaining == 540)

        let paused = running.paused(at: referenceDate.addingTimeInterval(100))
        #expect(paused.isPaused)
        #expect(paused.pausedRemaining == 500)
        #expect(paused.paused(at: referenceDate.addingTimeInterval(400)) == paused)
        #expect(paused.progress(at: referenceDate.addingTimeInterval(9_999)).remaining == 500)

        let resumed = paused.resumed(at: referenceDate.addingTimeInterval(1_000))
        #expect(!resumed.isPaused)
        #expect(resumed.endDate == referenceDate.addingTimeInterval(1_500))
        #expect(resumed.startDate == referenceDate.addingTimeInterval(900))
        #expect(resumed.phase == "Boil")
        #expect(running.resumed(at: referenceDate) == running)
    }

    @Test func scoreAlerts() throws {
        let attributes = ScoreActivityAttributes(
            league: "Pro Basketball",
            home: .init(name: "Harbor Hawks", abbreviation: "HAW", tint: .blue),
            away: .init(name: "Desert Foxes", abbreviation: "FOX", tint: .orange)
        )
        let before = ScoreActivityAttributes.ContentState(homeScore: 98, awayScore: 95, period: "Q4")
        let after = ScoreActivityAttributes.ContentState(homeScore: 100, awayScore: 95, period: "Q4")

        let alert = try #require(attributes.scoreAlert(from: before, to: after))
        #expect(alert.title == "Harbor Hawks score")
        #expect(alert.body == "HAW 100 \u{2013} 95 FOX")
        #expect(attributes.scoreAlert(from: before, to: before) == nil)
        #expect(attributes.team(.away).abbreviation == "FOX")
        #expect(attributes.accentTint == .blue)
        #expect(after.line.leader == .home)
    }

    @Test func rideLegs() {
        let attributes = RideActivityAttributes(pickup: "Ferry Building", destination: "Dolores Park")
        var state = RideActivityAttributes.ContentState(
            phase: .driverEnRoute,
            eta: referenceDate.addingTimeInterval(240),
            distanceRemaining: 850,
            legDistance: 3_400
        )
        #expect(attributes.legTarget(for: state) == "Ferry Building")
        #expect(state.progress.fraction == 0.75)
        state.phase = .onTrip
        #expect(attributes.legTarget(for: state) == "Dolores Park")
        #expect(attributes.staleDate(for: state, updatedAt: referenceDate) == referenceDate.addingTimeInterval(540))
    }

    @Test func statesRoundTripThroughJSON() throws {
        let state = DeliveryActivityAttributes.ContentState(
            stepIndex: 1,
            eta: referenceDate,
            courierName: "Mia",
            message: "3 stops before you"
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(DeliveryActivityAttributes.ContentState.self, from: data)
        #expect(decoded == state)

        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["stepIndex"] as? Int == 1)
        #expect(object["courierName"] as? String == "Mia")
    }

    @Test func attributesCarryTheirTintAsHex() throws {
        let data = try JSONEncoder().encode(delivery)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["tint"] as? String == "#FF6B00")
        #expect(object["merchant"] as? String == "Napoli Pizza")

        let decoded = try JSONDecoder().decode(DeliveryActivityAttributes.self, from: data)
        #expect(decoded == delivery)
    }

    @Test func aPushPayloadDecodes() throws {
        // The content-state of an APNs Live Activity push, as a server would send it. Dates use the default
        // JSONDecoder strategy (seconds since 2001-01-01), as ActivityKit does.
        let json = #"{"homeScore":101,"awayScore":99,"period":"Q4","clockText":"0:42","possession":"away","isFinal":false}"#
        let state = try JSONDecoder().decode(ScoreActivityAttributes.ContentState.self, from: Data(json.utf8))
        #expect(state.homeScore == 101)
        #expect(state.possession == .away)
        #expect(state.clockEnd == nil)
        #expect(state.clockText == "0:42")
    }

    @Test func presentations() {
        #expect(LiveActivityPresentation.allCases.count == 8)
        #expect(LiveActivityPresentation.allCases.filter(\.isCompact).count == 3)
        #expect(LiveActivityPresentation.allCases.filter(\.isExpanded).count == 4)
        #expect(!LiveActivityPresentation.lockScreen.isCompact)
        #expect(!LiveActivityPresentation.lockScreen.isExpanded)
    }
}
