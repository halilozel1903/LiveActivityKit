import Foundation
import Testing
@testable import LiveActivityKit

/// A clock tests move by hand.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date = referenceDate) {
        current = date
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}

@MainActor
@Suite("Live Activity controller")
struct ControllerTests {
    let attributes = TimerActivityAttributes(title: "Pasta", symbolName: "fork.knife")
    let backend = InMemoryActivityBackend<TimerActivityAttributes>()
    let clock = TestClock()

    func makeController(policy: LiveActivityUpdatePolicy = LiveActivityUpdatePolicy()) -> LiveActivityController<InMemoryActivityBackend<TimerActivityAttributes>> {
        let clock = self.clock
        return LiveActivityController(backend: backend, policy: policy, now: { clock.now })
    }

    func state(remaining: TimeInterval, phase: String = "Boil") -> TimerActivityAttributes.ContentState {
        TimerActivityAttributes.ContentState(
            startDate: referenceDate,
            endDate: referenceDate.addingTimeInterval(remaining),
            phase: phase
        )
    }

    @Test func start() throws {
        let controller = makeController()
        let id = try controller.start(attributes, state: state(remaining: 600), relevanceScore: 50)

        #expect(id == "activity-1")
        #expect(controller.isActive)
        #expect(controller.activityID == id)
        #expect(controller.attributes == attributes)
        #expect(controller.state == state(remaining: 600))
        #expect(controller.lastUpdate == referenceDate)
        // The default policy goes stale after 15 minutes.
        #expect(controller.staleDate == referenceDate.addingTimeInterval(900))
        #expect(controller.freshness == .fresh)

        let record = try #require(backend.records.last)
        #expect(record.kind == .request)
        #expect(record.content?.relevanceScore == 50)
        #expect(record.content?.staleDate == referenceDate.addingTimeInterval(900))
        #expect(backend.runningIDs == [id])
    }

    @Test func explicitStaleDate() throws {
        let controller = makeController()
        try controller.start(attributes, state: state(remaining: 600), staleDate: referenceDate.addingTimeInterval(60))
        #expect(controller.staleDate == referenceDate.addingTimeInterval(60))

        clock.advance(by: 50)
        #expect(controller.freshness == .aging)
        clock.advance(by: 10)
        #expect(controller.freshness == .stale)
    }

    @Test func startErrors() throws {
        let controller = makeController()

        backend.setEnabled(false)
        #expect(!controller.areActivitiesEnabled)
        #expect(throws: LiveActivityError.disabled) {
            try controller.start(attributes, state: state(remaining: 600))
        }

        backend.setEnabled(true)
        backend.failNextRequest(with: LiveActivityError.requestFailed("Too many activities"))
        #expect(throws: LiveActivityError.requestFailed("Too many activities")) {
            try controller.start(attributes, state: state(remaining: 600))
        }
        #expect(!controller.isActive)

        try controller.start(attributes, state: state(remaining: 600))
        #expect(throws: LiveActivityError.alreadyRunning) {
            try controller.start(attributes, state: state(remaining: 300))
        }
        #expect(backend.runningIDs.count == 1)
    }

    @Test func updates() async throws {
        let controller = makeController()
        try controller.start(attributes, state: state(remaining: 600))

        clock.advance(by: 30)
        let unchanged = await controller.update(state(remaining: 600))
        #expect(unchanged == .unchanged)
        #expect(backend.records.count == 1)

        let sent = await controller.update(state(remaining: 600, phase: "Drain"))
        #expect(sent == .sent)
        #expect(controller.state?.phase == "Drain")
        #expect(controller.lastUpdate == referenceDate.addingTimeInterval(30))
        #expect(controller.staleDate == referenceDate.addingTimeInterval(930))
        #expect(backend.records.last?.kind == .update)

        let alert = LiveActivityAlert(title: "Pasta", body: "Time to drain")
        let alerted = await controller.update(state(remaining: 600, phase: "Drain"), alert: alert)
        #expect(alerted == .sent)
        #expect(backend.records.last?.alert == alert)
    }

    @Test func throttledUpdates() async throws {
        let controller = makeController(policy: LiveActivityUpdatePolicy(maxAge: nil, minimumInterval: 10))
        try controller.start(attributes, state: state(remaining: 600))
        #expect(controller.staleDate == nil)

        clock.advance(by: 5)
        let throttled = await controller.update(state(remaining: 500))
        #expect(throttled == .throttled)
        #expect(controller.state == state(remaining: 600))

        let forced = await controller.update(state(remaining: 500), force: true)
        #expect(forced == .sent)

        clock.advance(by: 10)
        let later = await controller.update(state(remaining: 400))
        #expect(later == .sent)
    }

    @Test func end() async throws {
        let controller = makeController()
        let id = try controller.start(attributes, state: state(remaining: 600))

        await controller.end(state(remaining: 0, phase: "Done"), dismissal: .immediate)
        #expect(!controller.isActive)
        #expect(controller.state?.phase == "Done")
        let record = try #require(backend.records.last)
        #expect(record.kind == .end)
        #expect(record.id == id)
        #expect(record.dismissal == .immediate)
        #expect(record.content?.state.phase == "Done")
        #expect(backend.runningIDs.isEmpty)

        let afterEnd = await controller.update(state(remaining: 100))
        #expect(afterEnd == .notRunning)

        // A new activity can start once the old one ended.
        let next = try controller.start(attributes, state: state(remaining: 300))
        #expect(next == "activity-2")
    }

    @Test func pushTokens() async throws {
        let controller = makeController()
        var received: [String] = []
        controller.onPushToken = { received.append($0) }
        let id = try controller.start(attributes, state: state(remaining: 600), pushUpdates: true)

        backend.sendPushToken(Data([0xAB, 0xCD, 0x01]), for: id)
        for _ in 0..<200 where controller.pushToken == nil {
            await Task.yield()
        }
        #expect(controller.pushToken == "abcd01")

        // The same token again is not reported twice; a new one is.
        backend.sendPushToken(Data([0xAB, 0xCD, 0x01]), for: id)
        backend.sendPushToken(Data([0x02]), for: id)
        for _ in 0..<200 where controller.pushToken != "02" {
            await Task.yield()
        }
        #expect(controller.pushToken == "02")
        let expected: [String] = ["abcd01", "02"]
        #expect(received == expected)
    }

    @Test func updatesWithoutAnActivity() async {
        let controller = makeController()
        let result = await controller.update(state(remaining: 600))
        #expect(result == .notRunning)
        await controller.end()
        #expect(backend.records.isEmpty)
    }
}
