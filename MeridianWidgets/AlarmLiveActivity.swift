import AlarmKit
import SwiftUI
import WidgetKit

/// The snooze countdown AlarmKit shows after Snooze is tapped (decision BG). AlarmKit
/// needs a widget for alarms with a countdown, or the system may drop them.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<MeridianAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "alarm")
                    .foregroundStyle(Color.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(context.attributes, context.state))
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    AlarmCountdown(state: context.state)
                        .font(.title2.monospacedDigit())
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(.bgBase)
            .activitySystemActionForegroundColor(.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(title(context.attributes, context.state))
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        Spacer(minLength: 0)
                        AlarmCountdown(state: context.state)
                            .font(.title2.monospacedDigit())
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: "zzz").foregroundStyle(Color.textSecondary)
            } compactTrailing: {
                AlarmCountdown(state: context.state)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            } minimal: {
                Image(systemName: "zzz").foregroundStyle(Color.textSecondary)
            }
            .keylineTint(.accent)
        }
    }

    private func title(_ attributes: AlarmAttributes<MeridianAlarmMetadata>,
                       _ state: AlarmPresentationState) -> LocalizedStringResource {
        if case .countdown = state.mode, let countdown = attributes.presentation.countdown { return countdown.title }
        return attributes.presentation.alert.title
    }
}

/// Counts down to the next ring while snoozed; orange, as a Live Activity countdown (§3.2).
private struct AlarmCountdown: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .foregroundStyle(Color.accent)
        default:
            Text("Ringing")
                .foregroundStyle(Color.textSecondary)
        }
    }
}
