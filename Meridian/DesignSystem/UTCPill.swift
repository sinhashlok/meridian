import MeridianCore
import SwiftUI

/// Live `UTC 15:32:07` in the header. Tap flips the display (not inputs) to UTC
/// (spec §4.1); in UTC mode it gets an accent outline.
struct UTCPill: View {
    @Environment(AppState.self) private var appState
    /// Set on each whole second by `tick()`. Not a `TimelineView`: inside a toolbar item one
    /// kept the navigation bar re-laying out nonstop (iOS 27), freezing the app ~0.74 s a second.
    @State private var tickDate = Date.now

    var body: some View {
        Button {
            appState.isUTCMode.toggle()
        } label: {
            Group {
                let time = ClockFormat.utcTime(appState.now(tickDate))
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
        .task { await tick() }
    }

    /// Updates `tickDate` just after each whole second until the pill goes away.
    private func tick() async {
        while !Task.isCancelled {
            let intoSecond = Date.now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
            try? await Task.sleep(for: .seconds(1 - intoSecond))
            tickDate = .now
        }
    }
}

#Preview {
    UTCPill()
        .environment(AppState())
        .padding()
        .background(.bgBase)
}
