import SwiftUI

enum AlarmsSegment: String, CaseIterable, Identifiable {
    case alarms, jobs

    var id: Self { self }

    var title: String {
        switch self {
        case .alarms: "Alarms"
        case .jobs: "Jobs"
        }
    }
}

struct AlarmsTab: View {
    @AppStorage("alarms.segment") private var segment: AlarmsSegment = .alarms

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Picker("View", selection: $segment) {
                    ForEach(AlarmsSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screenMargin)

                switch segment {
                case .alarms:
                    AlarmSpikeView()  // M0.5 spike only
                case .jobs:
                    ContentUnavailableView(
                        segment.title,
                        systemImage: "calendar.badge.clock",
                        description: Text("Coming in M7")
                    )
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .meridianScreen(title: "Alarms")
        }
    }
}

#Preview {
    AlarmsTab()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
