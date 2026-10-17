import SwiftUI
import WidgetKit

/// Everything the widget extension shows: the timer and session Live Activities and the
/// alarm snooze countdown. Home and Lock Screen widgets arrive in M8.
@main
struct MeridianWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
        SessionLiveActivity()
        AlarmLiveActivity()
    }
}
