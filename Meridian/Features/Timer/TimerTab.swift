import SwiftUI

enum TimerSegment: String, CaseIterable, Identifiable {
    case timers, stopwatch

    var id: Self { self }

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
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Picker("View", selection: $segment) {
                    ForEach(TimerSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screenMargin)

                ContentUnavailableView(
                    segment.title,
                    systemImage: segment == .timers ? "timer" : "stopwatch",
                    description: Text("Coming in M5")
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .meridianScreen(title: "Timer")
        }
    }
}

#Preview {
    TimerTab()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
