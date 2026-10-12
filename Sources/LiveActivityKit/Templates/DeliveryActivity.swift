import Foundation
import SwiftUI
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// A food or parcel delivery: ordered, preparing, on the way, delivered.
///
/// ```swift
/// let attributes = DeliveryActivityAttributes(merchant: "Napoli Pizza", orderNumber: "4821")
/// let state = DeliveryActivityAttributes.ContentState(stepIndex: 2, eta: .now + 21 * 60, courierName: "Mia")
/// ```
public struct DeliveryActivityAttributes: LiveActivityTemplate {
    /// Who the order is from, such as "Napoli Pizza".
    public var merchant: String
    /// The order number shown under the merchant.
    public var orderNumber: String
    /// The titles of the steps, in order. The last one is the delivered state.
    public var steps: [String]
    /// The SF Symbol of the order, such as "bag.fill" or "shippingbox.fill".
    public var symbolName: String
    /// The accent color.
    public var tint: ActivityTint

    public init(
        merchant: String,
        orderNumber: String,
        steps: [String] = DeliveryActivityAttributes.defaultSteps,
        symbolName: String = "bag.fill",
        tint: ActivityTint = .orange
    ) {
        self.merchant = merchant
        self.orderNumber = orderNumber
        self.steps = steps
        self.symbolName = symbolName
        self.tint = tint
    }

    /// Ordered, Preparing, On the way, Delivered.
    public static let defaultSteps = ["Ordered", "Preparing", "On the way", "Delivered"]

    public struct ContentState: Codable, Hashable, Sendable {
        /// The index of the current step in ``DeliveryActivityAttributes/steps``. Out-of-range values are clamped.
        public var stepIndex: Int
        /// The expected arrival.
        public var eta: Date
        /// The courier's first name, once one is on the way.
        public var courierName: String?
        /// A line of detail, such as "3 stops before you".
        public var message: String?

        public init(stepIndex: Int, eta: Date, courierName: String? = nil, message: String? = nil) {
            self.stepIndex = stepIndex
            self.eta = eta
            self.courierName = courierName
            self.message = message
        }
    }

    /// The progress through ``steps`` for a state.
    public func progress(for state: ContentState) -> StepProgress {
        StepProgress(count: steps.count, currentIndex: state.stepIndex)
    }

    /// The title of the current step, or an empty string without steps.
    public func stepTitle(for state: ContentState) -> String {
        let current = progress(for: state).currentIndex
        return steps.indices.contains(current) ? steps[current] : ""
    }

    /// A stale date for `state`: ten minutes after the ETA, or `maxAge` after the update when that comes first.
    public func staleDate(for state: ContentState, updatedAt: Date, maxAge: TimeInterval = 1_800) -> Date {
        LiveActivityStaleness.staleDate(eta: state.eta, updatedAt: updatedAt, grace: 600, maxAge: maxAge)
    }

    public var accentTint: ActivityTint { tint }

    @MainActor
    public static func makeView(
        attributes: DeliveryActivityAttributes,
        state: ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool
    ) -> DeliveryActivityView {
        DeliveryActivityView(attributes: attributes, state: state, presentation: presentation, isStale: isStale)
    }
}

/// Every presentation of a ``DeliveryActivityAttributes`` activity.
public struct DeliveryActivityView: View {
    private let attributes: DeliveryActivityAttributes
    private let state: DeliveryActivityAttributes.ContentState
    private let presentation: LiveActivityPresentation
    private let isStale: Bool

    public init(
        attributes: DeliveryActivityAttributes,
        state: DeliveryActivityAttributes.ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool = false
    ) {
        self.attributes = attributes
        self.state = state
        self.presentation = presentation
        self.isStale = isStale
    }

    private var tint: Color { attributes.tint.color }
    private var progress: StepProgress { attributes.progress(for: state) }

    public var body: some View {
        switch presentation {
        case .lockScreen:
            lockScreen
        case .compactLeading:
            Image(systemName: attributes.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        case .compactTrailing:
            arrivalText
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        case .minimal:
            LiveActivityRing(fraction: progress.fraction, tint: tint) {
                Image(systemName: attributes.symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
            }
        case .expandedLeading:
            // The region beside the camera is too narrow for a name, so the merchant goes in the center region.
            LiveActivitySymbolBadge(systemName: attributes.symbolName, tint: attributes.tint, size: 36)
                .padding(.leading, 4)
        case .expandedTrailing:
            VStack(alignment: .trailing, spacing: 0) {
                arrivalText
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text(progress.isComplete ? "Delivered" : "Arriving")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 4)
        case .expandedCenter:
            VStack(spacing: 1) {
                Text(attributes.merchant)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("#" + attributes.orderNumber + " · " + attributes.stepTitle(for: state))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .expandedBottom:
            VStack(alignment: .leading, spacing: 8) {
                LiveActivityStepBar(progress: progress, tint: tint)
                detailLine
            }
            .padding(.horizontal, 4)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                LiveActivitySymbolBadge(systemName: attributes.symbolName, tint: attributes.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(attributes.merchant)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text("Order #" + attributes.orderNumber)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(progress.isComplete ? "Delivered" : "Arriving in")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    if !progress.isComplete {
                        arrivalText
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(tint)
                    }
                }
            }
            LiveActivityStepBar(progress: progress, titles: attributes.steps, tint: tint)
            detailLine
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var detailLine: some View {
        if isStale {
            LiveActivityStaleNote()
        } else if let line = detailText {
            Text(line)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    private var detailText: String? {
        switch (state.courierName, state.message) {
        case let (name?, message?): return name + " · " + message
        case let (name?, nil): return name + " is on the way"
        case let (nil, message?): return message
        case (nil, nil): return nil
        }
    }

    private var arrivalText: some View {
        LiveActivityCountdown(to: state.eta, style: .minutes)
    }
}

#if canImport(ActivityKit) && os(iOS)
extension DeliveryActivityAttributes: ActivityAttributes {}
#endif
