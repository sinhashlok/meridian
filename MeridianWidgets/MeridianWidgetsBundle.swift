import SwiftUI
import WidgetKit

/// Everything the widget extension shows: Home Screen widgets and Lock Screen accessories
/// (M8), the timer and session Live Activities and the alarm snooze countdown.
@main
struct MeridianWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        PlannerWidget()
        JobsWidget()
        NextJobAccessory()
        UTCAccessory()
        TimerLiveActivity()
        SessionLiveActivity()
        AlarmLiveActivity()
    }
}
