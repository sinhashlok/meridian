import SwiftUI
import WidgetKit

/// Everything the widget extension shows. M5: the timer Live Activity. Home and Lock
/// Screen widgets arrive in M8.
@main
struct MeridianWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
    }
}
