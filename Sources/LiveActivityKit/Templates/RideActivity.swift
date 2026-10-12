import Foundation
import SwiftUI
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// A ride: finding a driver, the driver on the way, the trip, arrival.
///
/// ```swift
/// let attributes = RideActivityAttributes(pickup: "Ferry Building", destination: "Mission Dolores Park")
/// let state = RideActivityAttributes.ContentState(
///     phase: .driverEnRoute, eta: .now + 240, distanceRemaining: 1_200, legDistance: 3_400,
///     driverName: "Alex", vehicle: "White Toyota Prius", plate: "8KZM 214"
/// )
/// ```
public struct RideActivityAttributes: LiveActivityTemplate {
    /// Where the rider is picked up.
    public var pickup: String
    /// Where the ride goes.
    public var destination: String
    /// The kind of ride, such as "Comfort".
    public var service: String
    /// The accent color.
    public var tint: ActivityTint

    public init(pickup: String, destination: String, service: String = "Ride", tint: ActivityTint = .green) {
        self.pickup = pickup
        self.destination = destination
        self.service = service
        self.tint = tint
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: RidePhase
        /// When the driver reaches the pickup (before the trip) or the destination (during it).
        public var eta: Date
        /// The distance left on the current leg, in meters.
        public var distanceRemaining: Double
        /// The whole distance of the current leg, in meters.
        public var legDistance: Double
        public var driverName: String?
        /// Color and model, such as "White Toyota Prius".
        public var vehicle: String?
        public var plate: String?

        public init(
            phase: RidePhase,
            eta: Date,
            distanceRemaining: Double,
            legDistance: Double,
            driverName: String? = nil,
            vehicle: String? = nil,
            plate: String? = nil
        ) {
            self.phase = phase
            self.eta = eta
            self.distanceRemaining = distanceRemaining
            self.legDistance = legDistance
            self.driverName = driverName
            self.vehicle = vehicle
            self.plate = plate
        }

        /// The progress of the current leg.
        public var progress: RideProgress {
            RideProgress(remaining: distanceRemaining, total: legDistance)
        }
    }

    /// What the current leg leads to: the pickup before the trip, the destination during it.
    public func legTarget(for state: ContentState) -> String {
        state.phase.isRiding ? destination : pickup
    }

    /// A stale date for `state`: five minutes after the ETA, or `maxAge` after the update when that comes first.
    public func staleDate(for state: ContentState, updatedAt: Date, maxAge: TimeInterval = 600) -> Date {
        LiveActivityStaleness.staleDate(eta: state.eta, updatedAt: updatedAt, grace: 300, maxAge: maxAge)
    }

    public var accentTint: ActivityTint { tint }

    @MainActor
    public static func makeView(
        attributes: RideActivityAttributes,
        state: ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool
    ) -> RideActivityView {
        RideActivityView(attributes: attributes, state: state, presentation: presentation, isStale: isStale)
    }
}

/// Every presentation of a ``RideActivityAttributes`` activity.
public struct RideActivityView: View {
    private let attributes: RideActivityAttributes
    private let state: RideActivityAttributes.ContentState
    private let presentation: LiveActivityPresentation
    private let isStale: Bool

    public init(
        attributes: RideActivityAttributes,
        state: RideActivityAttributes.ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool = false
    ) {
        self.attributes = attributes
        self.state = state
        self.presentation = presentation
        self.isStale = isStale
    }

    private var tint: Color { attributes.tint.color }

    private var symbolName: String {
        state.phase == .searching ? "magnifyingglass" : "car.fill"
    }

    public var body: some View {
        switch presentation {
        case .lockScreen:
            lockScreen
        case .compactLeading:
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        case .compactTrailing:
            etaText
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        case .minimal:
            LiveActivityRing(fraction: state.progress.fraction, tint: tint) {
                Image(systemName: symbolName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            }
        case .expandedLeading:
            VStack(alignment: .leading, spacing: 0) {
                etaText
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text(state.phase.isRiding ? "to destination" : "to pickup")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
        case .expandedTrailing:
            if let plate = state.plate {
                RidePlate(plate)
                    .padding(.trailing, 4)
            }
        case .expandedCenter:
            Text(state.phase.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        case .expandedBottom:
            VStack(spacing: 8) {
                RideRoute(progress: state.progress, from: legStart, to: attributes.legTarget(for: state), tint: tint)
                driverLine
            }
            .padding(.horizontal, 4)
        }
    }

    private var legStart: String {
        state.phase.isRiding ? attributes.pickup : "Driver"
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.phase.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    Text(attributes.service + " · " + state.progress.distanceText + " away")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                etaText
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            RideRoute(progress: state.progress, from: legStart, to: attributes.legTarget(for: state), tint: tint)
            if isStale {
                LiveActivityStaleNote()
            } else {
                driverLine
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var driverLine: some View {
        if let driverName = state.driverName {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.8))
                VStack(alignment: .leading, spacing: 0) {
                    Text(driverName)
                        .font(.system(size: 13, weight: .semibold))
                    if let vehicle = state.vehicle {
                        Text(vehicle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                if presentation == .lockScreen, let plate = state.plate {
                    RidePlate(plate)
                }
            }
        }
    }

    @ViewBuilder
    private var etaText: some View {
        if state.phase.isFinished {
            Text("Now")
        } else {
            LiveActivityCountdown(to: state.eta, style: .minutes)
        }
    }
}

/// A route line from one place to another with the car at the current progress.
public struct RideRoute: View {
    private let progress: RideProgress
    private let from: String
    private let to: String
    private let tint: Color

    public init(progress: RideProgress, from: String, to: String, tint: Color) {
        self.progress = progress
        self.from = from
        self.to = to
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let carX = 10 + (width - 20) * CGFloat(progress.fraction)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(tint)
                        .frame(width: carX, height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white, tint)
                        .offset(x: width - 16)
                    Image(systemName: "car.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint.opacity(1))
                        .padding(4)
                        .background(Color.white, in: Circle())
                        .offset(x: carX - 12)
                }
                .frame(height: proxy.size.height)
            }
            .frame(height: 24)
            HStack {
                Text(from)
                Spacer(minLength: 12)
                Text(to)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((progress.fraction * 100).rounded())) percent of the way from \(from) to \(to)")
    }
}

/// A license plate badge.
public struct RidePlate: View {
    private let plate: String

    public init(_ plate: String) {
        self.plate = plate
    }

    public var body: some View {
        Text(plate)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

#if canImport(ActivityKit) && os(iOS)
extension RideActivityAttributes: ActivityAttributes {}
#endif
