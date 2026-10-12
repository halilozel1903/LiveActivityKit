import Foundation

/// The stages of a ride.
public enum RidePhase: String, Codable, Hashable, Sendable, CaseIterable {
    /// Looking for a driver.
    case searching
    /// A driver accepted and is driving to the pickup.
    case driverEnRoute
    /// The driver is at, or about to reach, the pickup.
    case arriving
    /// On the way to the destination.
    case onTrip
    /// At the destination.
    case arrived

    /// A short title for the Lock Screen: "Driver on the way".
    public var title: String {
        switch self {
        case .searching: return "Finding your driver"
        case .driverEnRoute: return "Driver on the way"
        case .arriving: return "Driver arriving"
        case .onTrip: return "On your way"
        case .arrived: return "You have arrived"
        }
    }

    /// `true` while the rider is in the car or has arrived.
    public var isRiding: Bool {
        self == .onTrip || self == .arrived
    }

    /// `true` once the ride is over.
    public var isFinished: Bool {
        self == .arrived
    }
}

/// How far along a leg of a ride is, from the distance left and the leg's whole distance.
///
/// ```swift
/// let progress = RideProgress(remaining: 1_200, total: 4_800)
/// progress.fraction         // 0.75
/// progress.distanceText     // "1.2 km"
/// ```
public struct RideProgress: Hashable, Sendable {
    /// The distance left, in meters, from 0 to ``total``.
    public let remaining: Double
    /// The leg's distance, in meters, never negative.
    public let total: Double

    public init(remaining: Double, total: Double) {
        let total = total.isFinite ? max(0, total) : 0
        self.total = total
        self.remaining = remaining.isFinite ? min(max(0, remaining), total) : total
    }

    /// How much of the leg is done, from 0 to 1. A leg without a distance is done.
    public var fraction: Double {
        guard total > 0 else { return 1 }
        return (total - remaining) / total
    }

    /// The distance left as text: "450 m", "1.2 km".
    public var distanceText: String {
        ETAFormatter.distance(meters: remaining)
    }
}
