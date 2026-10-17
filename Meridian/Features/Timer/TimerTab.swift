import SwiftData
import SwiftUI

enum TimerSegment: String, ScreenSegment {
    case timers, stopwatch

    var title: String {
        switch self {
        case .timers: "Timers"
        case .stopwatch: "Stopwatch"
        }
    }
}

struct TimerTab: View {
    @AppStorage("timer.segment") private var segment: TimerSegment = .timers

    var body: some View {
        SegmentedScreen(title: "Timer", segment: $segment) { segment in
            switch segment {
            case .timers: TimersView()
            case .stopwatch: StopwatchView()
            }
        }
    }
}

#Preview {
    TimerTab()
        .environment(AppState())
        .modelContainer(for: [SavedTimer.self, SavedZone.self], inMemory: true)
        .preferredColorScheme(.dark)
}
