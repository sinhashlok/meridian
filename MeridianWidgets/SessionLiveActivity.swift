import ActivityKit
import SwiftUI
import WidgetKit

/// The session Live Activity (spec §4.5, decision AZ). The content views are in
/// `Shared/LiveActivityViews.swift`. Lock Screen per board LiveActivity; Dynamic Island
/// per board Island (compact ring + countdown, minimal ring, expanded with buttons).
/// Tapping opens Sessions.
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionLockScreenView(state: context.state)
                .activityBackgroundTint(.bgBase)
                .activitySystemActionForegroundColor(.textPrimary)
                .widgetURL(SessionActivityLink.url)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                // One full-width region, so the top row can span ring → countdown as on the board.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        SessionExpandedTop(state: state)
                        SessionExpandedBottom(state: state)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                SessionRing(state: state).frame(width: 22, height: 22)
            } compactTrailing: {
                // Orange while focusing: a Live Activity countdown (§3.2).
                LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                    .monospacedDigit()
                    .foregroundStyle(state.isFocus && !state.isPaused ? Color.accent : .textSecondary)
                    .frame(width: 52, alignment: .trailing)
            } minimal: {
                SessionRing(state: state).frame(width: 22, height: 22)
            }
            .widgetURL(SessionActivityLink.url)
            .keylineTint(.accent)
        }
    }
}

/// `meridian://sessions`: opens the app on Sessions.
enum SessionActivityLink {
    static let url = URL(string: "meridian://sessions")!
}

#Preview("Lock Screen", as: .content, using: SessionActivityAttributes()) {
    SessionLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.sample
    SessionActivityAttributes.ContentState.sampleNoWindow
    SessionActivityAttributes.ContentState.samplePaused
}
