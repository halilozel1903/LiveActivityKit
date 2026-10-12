import LiveActivityKit
import SwiftUI
import WidgetKit

/// The widget extension that draws the demo's Live Activities on the Lock Screen and in the Dynamic Island.
/// Each template of LiveActivityKit is one widget: its Lock Screen view and a full Dynamic Island.
@main
struct LiveActivityWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DeliveryLiveActivity()
        TimerLiveActivity()
        ScoreLiveActivity()
        RideLiveActivity()
    }
}
