import Foundation
import SwiftUI

/// The attributes of a Live Activity, on every platform.
///
/// ActivityKit's `ActivityAttributes` exists only on iOS. This protocol has the same shape (static attributes plus a
/// `ContentState` that changes with each update), so templates, their views, the controller and the tests compile and
/// run on macOS too. On iOS every template also conforms to `ActivityAttributes`.
public protocol LiveActivityAttributes: Codable, Hashable, Sendable {
    /// The part of the activity that changes with each update or push.
    associatedtype ContentState: Codable, Hashable, Sendable
}

/// Where a Live Activity is drawn: the Lock Screen (and StandBy, and the banner on devices without a Dynamic
/// Island), or one of the Dynamic Island's presentations.
public enum LiveActivityPresentation: String, Hashable, Sendable, CaseIterable {
    /// The Lock Screen banner, up to 160 points tall.
    case lockScreen
    /// Left of the camera, when the island is compact.
    case compactLeading
    /// Right of the camera, when the island is compact.
    case compactTrailing
    /// A small circle, when another activity shares the island.
    case minimal
    /// The leading region of the expanded island, beside the camera.
    case expandedLeading
    /// The trailing region of the expanded island, beside the camera.
    case expandedTrailing
    /// The center region of the expanded island, below the camera.
    case expandedCenter
    /// The bottom region of the expanded island.
    case expandedBottom

    /// `true` for the two compact presentations and the minimal one, which have room for a few characters only.
    public var isCompact: Bool {
        self == .compactLeading || self == .compactTrailing || self == .minimal
    }

    /// `true` for the four regions of the expanded island.
    public var isExpanded: Bool {
        self == .expandedLeading || self == .expandedTrailing || self == .expandedCenter || self == .expandedBottom
    }
}

/// A template: attributes that know how to draw themselves in every presentation.
///
/// The four templates of this package conform, and so can your own attributes. `LiveActivityTemplateWidget` (iOS)
/// turns any template into a widget with a Lock Screen view and a full Dynamic Island.
public protocol LiveActivityTemplate: LiveActivityAttributes {
    associatedtype TemplateView: View

    /// The view for `presentation`. `isStale` is ActivityKit's `context.isStale`: the content is past its stale date.
    @MainActor
    static func makeView(
        attributes: Self,
        state: ContentState,
        presentation: LiveActivityPresentation,
        isStale: Bool
    ) -> TemplateView

    /// The accent of the activity: the Dynamic Island's keyline and the tint of its symbols.
    var accentTint: ActivityTint { get }
}

/// What a start or an update sends: the state, when it goes stale and how relevant it is among several activities.
public struct LiveActivityContent<State: Codable & Hashable & Sendable>: Hashable, Sendable {
    public var state: State
    /// When the system should mark the content stale if no update arrives.
    public var staleDate: Date?
    /// Higher scores are shown first when several activities run; 0 to 100 by convention.
    public var relevanceScore: Double

    public init(state: State, staleDate: Date? = nil, relevanceScore: Double = 0) {
        self.state = state
        self.staleDate = staleDate
        self.relevanceScore = relevanceScore
    }
}

/// An alert that lights up the screen and expands the Dynamic Island with an update, such as "Your order is here".
public struct LiveActivityAlert: Hashable, Sendable {
    public var title: String
    public var body: String
    /// A sound file in the app bundle; `nil` plays the default sound.
    public var soundName: String?

    public init(title: String, body: String, soundName: String? = nil) {
        self.title = title
        self.body = body
        self.soundName = soundName
    }
}

/// When an ended Live Activity leaves the Lock Screen.
public enum LiveActivityDismissal: Hashable, Sendable {
    /// After a while (up to four hours), the system decides.
    case `default`
    /// Right away.
    case immediate
    /// At a date within the next four hours.
    case after(Date)
}

/// Errors thrown when starting a Live Activity.
public enum LiveActivityError: Error, Equatable, Sendable, LocalizedError {
    /// Live Activities are turned off in Settings, or the device does not support them.
    case disabled
    /// The controller already runs an activity; end it first.
    case alreadyRunning
    /// The system refused the request, for example because too many activities are running.
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .disabled: return "Live Activities are turned off for this app."
        case .alreadyRunning: return "A Live Activity is already running."
        case let .requestFailed(reason): return reason
        }
    }
}
