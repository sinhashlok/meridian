import MeridianCore
import SwiftUI

/// Live `UTC 15:32:07` in the header. Tap flips the display (not inputs) to UTC
/// (spec §4.1); in UTC mode it gets an accent outline.
struct UTCPill: View {
    @Environment(AppState.self) private var appState

    /// Ticks land on whole seconds because the schedule starts on a whole second.
    private static let everySecond = PeriodicTimelineSchedule(
        from: Date(timeIntervalSinceReferenceDate: 0), by: 1
    )

    var body: some View {
        Button {
            appState.isUTCMode.toggle()
        } label: {
            TimelineView(Self.everySecond) { context in
                let time = ClockFormat.utcTime(context.date)
                Text("UTC \(time)")
                    .meridianFont(.monoCaption)
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xxs)
                    .background(.bgSurface, in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(appState.isUTCMode ? Color.accent : Color.clear, lineWidth: 1.5)
                    }
                    .accessibilityLabel("UTC \(time)")
            }
            .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // The toolbar offers a narrow slot; report the pill's full width so it is never truncated.
        .fixedSize()
        .animation(Motion.stateChange, value: appState.isUTCMode)
        .sensoryFeedback(Haptic.utcFlip, trigger: appState.isUTCMode)
        .accessibilityAddTraits(appState.isUTCMode ? .isSelected : [])
        .accessibilityHint(appState.isUTCMode ? "Shows times in their own zones" : "Shows all times in UTC")
    }
}

#Preview {
    UTCPill()
        .environment(AppState())
        .padding()
        .background(.bgBase)
}
