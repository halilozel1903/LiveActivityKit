#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

/// A widget for any ``LiveActivityTemplate``: its Lock Screen view on a dark banner and a full Dynamic Island
/// (compact, minimal and expanded) with the template's keyline tint.
///
/// Add one per template to your widget extension's bundle:
///
/// ```swift
/// @main
/// struct Widgets: WidgetBundle {
///     var body: some Widget {
///         DeliveryLiveActivity()
///         TimerLiveActivity()
///     }
/// }
/// ```
public struct LiveActivityTemplateWidget<Attributes: LiveActivityTemplate & ActivityAttributes>: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: Attributes.self) { context in
            Attributes.makeView(
                attributes: context.attributes,
                state: context.state,
                presentation: .lockScreen,
                isStale: context.isStale
            )
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.62))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .expandedLeading, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .expandedTrailing, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.center) {
                    Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .expandedCenter, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .expandedBottom, isStale: context.isStale)
                }
            } compactLeading: {
                Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .compactLeading, isStale: context.isStale)
            } compactTrailing: {
                Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .compactTrailing, isStale: context.isStale)
            } minimal: {
                Attributes.makeView(attributes: context.attributes, state: context.state, presentation: .minimal, isStale: context.isStale)
            }
            .keylineTint(context.attributes.accentTint.color)
        }
    }
}

/// The delivery template as a Live Activity widget.
public typealias DeliveryLiveActivity = LiveActivityTemplateWidget<DeliveryActivityAttributes>
/// The timer template as a Live Activity widget.
public typealias TimerLiveActivity = LiveActivityTemplateWidget<TimerActivityAttributes>
/// The score template as a Live Activity widget.
public typealias ScoreLiveActivity = LiveActivityTemplateWidget<ScoreActivityAttributes>
/// The ride template as a Live Activity widget.
public typealias RideLiveActivity = LiveActivityTemplateWidget<RideActivityAttributes>
#endif
