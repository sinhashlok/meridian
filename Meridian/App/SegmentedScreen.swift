import SwiftUI

/// A tab's segments (spec §2), e.g. Planner · Clocks. A `String` raw value lets
/// `@AppStorage("<tab>.segment")` remember the last one.
protocol ScreenSegment: Hashable, Identifiable, CaseIterable, RawRepresentable<String>
where AllCases: RandomAccessCollection {
    var title: String { get }
}

extension ScreenSegment {
    var id: Self { self }
}

/// The shell every segmented tab shares: header (`meridianScreen`), the native segmented
/// control with the selection haptic (§3.4), then the chosen segment's content.
struct SegmentedScreen<Segment: ScreenSegment, Content: View>: View {
    let title: String
    @Binding var segment: Segment
    @ViewBuilder let content: (Segment) -> Content

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Picker("\(title) view", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screenMargin)
                .sensoryFeedback(Haptic.selection, trigger: segment)

                content(segment)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .meridianScreen(title: title)
        }
    }
}
