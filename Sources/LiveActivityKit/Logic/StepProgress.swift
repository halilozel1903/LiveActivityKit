import Foundation

/// Where one step of a multi-step Live Activity stands.
public enum StepState: String, Codable, Hashable, Sendable, CaseIterable {
    /// The step is done.
    case completed
    /// The step is happening now.
    case current
    /// The step has not started yet.
    case upcoming
}

/// Progress through an ordered list of steps, such as Ordered → Preparing → On the way → Delivered.
///
/// ```swift
/// let progress = StepProgress(count: 4, currentIndex: 2)
/// progress.states        // [.completed, .completed, .current, .upcoming]
/// progress.fraction      // 0.666…
/// progress.isComplete    // false
/// ```
///
/// The current index is clamped to the steps, so a push with an out-of-range index never crashes a view. Reaching the
/// last step completes the whole list: the last step then reads `.completed`, not `.current`.
public struct StepProgress: Hashable, Sendable {
    /// The number of steps, never negative.
    public let count: Int
    /// The index of the current step, clamped to `0..<count` (0 when there are no steps).
    public let currentIndex: Int

    public init(count: Int, currentIndex: Int) {
        let count = max(0, count)
        self.count = count
        self.currentIndex = count == 0 ? 0 : min(max(0, currentIndex), count - 1)
    }

    /// `true` once the last step has been reached.
    public var isComplete: Bool {
        count > 0 && currentIndex == count - 1
    }

    /// The state of the step at `index`. Indices before the list are completed, indices after it upcoming.
    public func state(at index: Int) -> StepState {
        guard count > 0 else { return .upcoming }
        if index < currentIndex { return .completed }
        if index == currentIndex { return isComplete ? .completed : .current }
        return .upcoming
    }

    /// The state of every step, in order.
    public var states: [StepState] {
        (0..<count).map { state(at: $0) }
    }

    /// How far along the list is, from 0 (first step) to 1 (last step). A single step is always complete.
    public var fraction: Double {
        guard count > 1 else { return count == 1 ? 1 : 0 }
        return Double(currentIndex) / Double(count - 1)
    }

    /// The number of steps still to reach.
    public var remainingSteps: Int {
        count == 0 ? 0 : count - 1 - currentIndex
    }

    /// The number of completed steps.
    public var completedCount: Int {
        states.filter { $0 == .completed }.count
    }

    /// The progress `steps` steps later (or earlier, when negative), clamped to the list.
    public func advanced(by steps: Int = 1) -> StepProgress {
        StepProgress(count: count, currentIndex: currentIndex + steps)
    }
}
