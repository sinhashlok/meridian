import ActivityKit
import SwiftUI
import WidgetKit

/// The timer Live Activity (spec §6, decision AQ): the soonest timer large, "+N more",
/// with Pause / +1 min / Cancel (decision BA). The content views are in
/// `Shared/LiveActivityViews.swift`. Tapping opens Timer.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            TimerLockScreenView(state: context.state)
                .activityBackgroundTint(.bgBase)
                .activitySystemActionForegroundColor(.textPrimary)
                .widgetURL(TimerActivityLink.url)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        TimerExpandedTop(state: state)
                        TimerExpandedBottom(state: state)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                TimerRing(state: state).frame(width: 22, height: 22)
            } compactTrailing: {
                // Orange: a Live Activity countdown (§3.2).
                LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                    .monospacedDigit()
                    .foregroundStyle(state.isPaused ? Color.textSecondary : .accent)
                    .frame(width: 52, alignment: .trailing)
            } minimal: {
                TimerRing(state: state).frame(width: 22, height: 22)
            }
            .widgetURL(TimerActivityLink.url)
            .keylineTint(.accent)
        }
    }
}

/// `meridian://timer`: opens the app on the Timer tab.
enum TimerActivityLink {
    static let url = URL(string: "meridian://timer")!
}

#Preview("Lock Screen", as: .content, using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.sample
    TimerActivityAttributes.ContentState.sampleUntil
}
