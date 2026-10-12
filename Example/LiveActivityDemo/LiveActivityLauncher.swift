import Foundation
import LiveActivityKit
import Observation

/// Starts real Live Activities from the gallery with ActivityKit, steps them forward and ends them.
/// Lock the simulator (Device › Lock) to see them on the Lock Screen; an iPhone with a Dynamic Island shows them there.
@MainActor
@Observable
final class LiveActivityLauncher {
    enum Kind: String, CaseIterable, Identifiable {
        case delivery
        case timer
        case score
        case ride

        var id: String { rawValue }
    }

    let delivery = ActivityController<DeliveryActivityAttributes>()
    let timer = ActivityController<TimerActivityAttributes>()
    let score = ActivityController<ScoreActivityAttributes>()
    let ride = ActivityController<RideActivityAttributes>()

    /// The result of the last action, shown under the buttons.
    var message: String?

    func isActive(_ kind: Kind) -> Bool {
        switch kind {
        case .delivery: delivery.isActive
        case .timer: timer.isActive
        case .score: score.isActive
        case .ride: ride.isActive
        }
    }

    func start(_ kind: Kind) {
        let now = Date()
        do {
            switch kind {
            case .delivery:
                let state = DemoData.deliveryState(at: now)
                try delivery.start(DemoData.delivery, state: state, staleDate: DemoData.delivery.staleDate(for: state, updatedAt: now))
            case .timer:
                let state = DemoData.timerState(at: now)
                try timer.start(DemoData.timer, state: state, staleDate: state.endDate.addingTimeInterval(60))
            case .score:
                try score.start(DemoData.score, state: DemoData.scoreState(at: now), relevanceScore: 100)
            case .ride:
                let state = DemoData.rideState(at: now)
                try ride.start(DemoData.ride, state: state, staleDate: DemoData.ride.staleDate(for: state, updatedAt: now))
            }
            message = "Started. Lock the simulator to see it on the Lock Screen."
        } catch {
            message = error.localizedDescription
        }
    }

    /// Moves the activity one step: the next delivery step, pause or resume, a basket, the next ride phase.
    func advance(_ kind: Kind) async {
        let now = Date()
        switch kind {
        case .delivery:
            guard var state = delivery.state else { return }
            state.stepIndex = min(state.stepIndex + 1, DemoData.delivery.steps.count - 1)
            state.eta = max(now, state.eta.addingTimeInterval(-8 * 60))
            let delivered = state.stepIndex == DemoData.delivery.steps.count - 1
            if delivered {
                state.message = "Enjoy your meal"
            }
            let alert = delivered ? LiveActivityAlert(title: "Delivered", body: "Your order from Napoli Pizza is here.") : nil
            await delivery.update(state, staleDate: DemoData.delivery.staleDate(for: state, updatedAt: now), alert: alert)
        case .timer:
            guard let state = timer.state else { return }
            let next = state.isPaused ? state.resumed(at: now) : state.paused(at: now)
            await timer.update(next, staleDate: next.isPaused ? nil : next.endDate.addingTimeInterval(60))
        case .score:
            guard let state = score.state else { return }
            var next = state
            if state.homeScore <= state.awayScore + 3 {
                next.homeScore += 2
                next.lastPlay = "#7 Okafor · layup"
                next.possession = .away
            } else {
                next.awayScore += 3
                next.lastPlay = "#11 Brandt · 3-pt jumper"
                next.possession = .home
            }
            await score.update(next, alert: DemoData.score.scoreAlert(from: state, to: next))
        case .ride:
            guard var state = ride.state else { return }
            switch state.phase {
            case .searching:
                state.phase = .driverEnRoute
            case .driverEnRoute:
                state.phase = .arriving
                state.distanceRemaining = 60
                state.eta = now.addingTimeInterval(60)
            case .arriving:
                state.phase = .onTrip
                state.legDistance = 5_200
                state.distanceRemaining = 5_200
                state.eta = now.addingTimeInterval(14 * 60)
            case .onTrip, .arrived:
                state.phase = .arrived
                state.distanceRemaining = 0
                state.eta = now
            }
            let alert = state.phase == .arriving ? LiveActivityAlert(title: "Your driver is here", body: "Look for the white Prius, 8KZM214.") : nil
            await ride.update(state, staleDate: DemoData.ride.staleDate(for: state, updatedAt: now), alert: alert)
        }
        message = nil
    }

    func end(_ kind: Kind) async {
        switch kind {
        case .delivery: await delivery.end(dismissal: .immediate)
        case .timer: await timer.end(dismissal: .immediate)
        case .score: await score.end(dismissal: .immediate)
        case .ride: await ride.end(dismissal: .immediate)
        }
        message = "Ended."
    }
}
