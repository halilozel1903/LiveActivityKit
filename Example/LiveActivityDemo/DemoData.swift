import Foundation
import LiveActivityKit

/// The made-up orders, timers, matches and rides the gallery shows.
///
/// The gallery draws everything at ``now`` with `liveActivityNow(_:)`, so countdowns read the same in every frame and
/// every screenshot. Real Live Activities started from the gallery use the same data relative to the current time.
enum DemoData {
    /// Thursday, October 8, 2026, 18:20 UTC.
    static let now = Date(timeIntervalSince1970: 1_791_484_800)

    // MARK: Delivery

    static let delivery = DeliveryActivityAttributes(
        merchant: "Napoli Pizza",
        orderNumber: "4821",
        symbolName: "takeoutbag.and.cup.and.straw.fill",
        tint: .orange
    )

    static func deliveryState(at now: Date) -> DeliveryActivityAttributes.ContentState {
        DeliveryActivityAttributes.ContentState(
            stepIndex: 2,
            eta: now.addingTimeInterval(21 * 60),
            courierName: "Mia",
            message: "3 stops before you"
        )
    }

    // MARK: Timer

    static let timer = TimerActivityAttributes(title: "Pasta", symbolName: "timer", tint: .yellow)

    static func timerState(at now: Date) -> TimerActivityAttributes.ContentState {
        TimerActivityAttributes.ContentState(
            startDate: now.addingTimeInterval(-150),
            endDate: now.addingTimeInterval(390),
            phase: "Boil"
        )
    }

    // MARK: Score

    static let score = ScoreActivityAttributes(
        league: "Pro Basketball",
        home: .init(name: "Harbor Hawks", abbreviation: "HAW", tint: ActivityTint(hex: "#0A84FF") ?? .blue),
        away: .init(name: "Desert Foxes", abbreviation: "FOX", tint: ActivityTint(hex: "#F2552C") ?? .orange)
    )

    static func scoreState(at now: Date) -> ScoreActivityAttributes.ContentState {
        ScoreActivityAttributes.ContentState(
            homeScore: 98,
            awayScore: 95,
            period: "Q4",
            clockEnd: now.addingTimeInterval(252),
            lastPlay: "#23 Rivers · 3-pt jumper",
            possession: .home
        )
    }

    // MARK: Ride

    static let ride = RideActivityAttributes(
        pickup: "Ferry Building",
        destination: "Mission Dolores Park",
        service: "Comfort",
        tint: .green
    )

    static func rideState(at now: Date) -> RideActivityAttributes.ContentState {
        RideActivityAttributes.ContentState(
            phase: .driverEnRoute,
            eta: now.addingTimeInterval(4 * 60),
            distanceRemaining: 850,
            legDistance: 3_400,
            driverName: "Alex",
            vehicle: "White Toyota Prius",
            plate: "8KZM214"
        )
    }
}
