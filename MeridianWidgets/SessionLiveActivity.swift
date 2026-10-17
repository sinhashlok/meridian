import ActivityKit
import SwiftUI
import WidgetKit

/// The session Live Activity (spec §4.5, decision AZ). Lock Screen per board LiveActivity:
/// phase and end, a large countdown, the draining bar and the meeting line. Dynamic Island
/// per board Island: compact ring + countdown, minimal ring, expanded with phase, end,
/// countdown and the meeting line. Tapping opens Sessions.
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
                DynamicIslandExpandedRegion(.leading) {
                    SessionRing(state: state)
                        .frame(width: 44, height: 44)
                        .padding(.leading, Spacing.xxs)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.phase)
                            .meridianFont(.headline)
                            .foregroundStyle(.textPrimary)
                        Text(state.ends)
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                        .font(.system(size: 40, weight: .light).monospacedDigit())
                        .foregroundStyle(.textPrimary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MeetingLines(state: state)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                SessionRing(state: state).frame(width: 20, height: 20)
            } compactTrailing: {
                // Orange while focusing: a Live Activity countdown (§3.2).
                LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                    .monospacedDigit()
                    .foregroundStyle(state.isFocus && state.endDate != nil ? Color.accent : .textSecondary)
                    .frame(maxWidth: 64)
            } minimal: {
                SessionRing(state: state).frame(width: 20, height: 20)
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

// MARK: - Lock Screen

private struct SessionLockScreenView: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "scope")
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
                Text("\(state.phase) · \(state.ends)")
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            .meridianFont(.sub)

            LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                .font(.system(size: 48, weight: .light).monospacedDigit())
                .foregroundStyle(.textPrimary)

            LiveProgress(shape: .bar, start: state.phaseStart, end: state.endDate, pausedFraction: state.pausedFraction,
                         tint: sessionTint(state))

            MeetingLines(state: state)
        }
        .padding(Spacing.m)
    }
}

// MARK: - Parts

private struct SessionRing: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        LiveProgress(shape: .ring, start: state.phaseStart, end: state.endDate, pausedFraction: state.pausedFraction,
                     tint: sessionTint(state))
    }
}

/// `Best compromise in 21 min` / `16:00 UTC · 3 of 3 awake · Mumbai in stretch`.
private struct MeetingLines: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        if let title = state.meetingTitle {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
                if let detail = state.meetingDetail {
                    Text(detail)
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }
}

/// Focus accent, break `textSecondary`, paused `textTertiary` (as in the app).
private func sessionTint(_ state: SessionActivityAttributes.ContentState) -> Color {
    state.endDate == nil ? .textTertiary : state.isFocus ? .accent : .textSecondary
}

// MARK: - Previews

extension SessionActivityAttributes.ContentState {
    /// Board LiveActivity: Focus 1 of 4 with 18:42 left.
    fileprivate static var board: Self {
        Self(phase: "Focus · 1 of 4", ends: "Ends 21:28 IST", isFocus: true, endDate: .now.addingTimeInterval(1122),
             phaseStart: .now.addingTimeInterval(-378), pausedRemaining: nil, pausedFraction: nil,
             meetingTitle: "Best compromise in 21 min", meetingDetail: "16:00 UTC · 3 of 3 awake · Mumbai in stretch")
    }

    fileprivate static var paused: Self {
        Self(phase: "Focus · 1 of 4", ends: "Paused", isFocus: true, endDate: nil, phaseStart: nil,
             pausedRemaining: "18:42", pausedFraction: 0.748, meetingTitle: nil, meetingDetail: nil)
    }
}

#Preview("Lock Screen", as: .content, using: SessionActivityAttributes()) {
    SessionLiveActivity()
} contentStates: {
    SessionActivityAttributes.ContentState.board
    SessionActivityAttributes.ContentState.paused
}
