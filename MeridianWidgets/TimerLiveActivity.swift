import ActivityKit
import SwiftUI
import WidgetKit

/// The timer Live Activity (spec §6, decision AQ): the soonest timer large, "+N more".
/// Lock Screen in the style of board LiveActivity; Dynamic Island compact (ring +
/// countdown), minimal (ring) and expanded. Display-only in M5: tapping opens Timer.
///
/// Live Activities can't run our own clock code, so running timers use the system's
/// self-updating `Text(timerInterval:)` and `ProgressView(timerInterval:)` (decision AK:
/// these print `6:42`, not `06:42`). Everything else arrives pre-formatted.
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(.bgBase)
                .activitySystemActionForegroundColor(.textPrimary)
                .widgetURL(TimerActivityLink.url)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Ring(state: state)
                        .frame(width: 44, height: 44)
                        .padding(.leading, Spacing.xxs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                        .font(.system(size: 40, weight: .light).monospacedDigit())
                        .foregroundStyle(.textPrimary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(state.title)
                            .meridianFont(.headline)
                            .foregroundStyle(.textPrimary)
                        Text([state.caption, state.more].compactMap(\.self).joined(separator: " · "))
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Ring(state: state).frame(width: 20, height: 20)
            } compactTrailing: {
                // Orange: a Live Activity countdown (§3.2).
                LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                    .monospacedDigit()
                    .foregroundStyle(.accent)
                    .frame(maxWidth: 64)
            } minimal: {
                Ring(state: state).frame(width: 20, height: 20)
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

// MARK: - Lock Screen

private struct LockScreenView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "timer")
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
                Text("\(state.title) · \(state.caption)")
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let more = state.more {
                    Text(more).foregroundStyle(.textSecondary)
                }
            }
            .meridianFont(.sub)

            LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                .font(.system(size: 48, weight: .light).monospacedDigit())
                .foregroundStyle(.textPrimary)

            LiveProgress(shape: .bar, start: state.progressStart, end: state.endDate,
                         pausedFraction: state.pausedFraction, tint: state.endDate == nil ? .textTertiary : .accent)
        }
        .padding(Spacing.m)
    }
}

// MARK: - Parts

/// Ring for the Island: drains with the timer; a timer glyph for Until timers.
private struct Ring: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.progressStart != nil || state.pausedFraction != nil {
            LiveProgress(shape: .ring, start: state.progressStart, end: state.endDate,
                         pausedFraction: state.pausedFraction, tint: state.endDate == nil ? .textTertiary : .accent)
        } else {
            Image(systemName: "timer")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.accent)
        }
    }
}

// MARK: - Previews

extension TimerActivityAttributes.ContentState {
    /// Board TimerUntil's Standup prep, 06:42 left.
    fileprivate static var standup: Self {
        Self(title: "Standup prep", caption: "Ends 21:16 IST", endDate: .now.addingTimeInterval(402),
             progressStart: .now.addingTimeInterval(-198), pausedRemaining: nil, pausedFraction: nil, more: "+1 more")
    }

    fileprivate static var paused: Self {
        Self(title: "Standup prep", caption: "Paused", endDate: nil, progressStart: nil,
             pausedRemaining: "06:42", pausedFraction: 0.67, more: nil)
    }
}

#Preview("Lock Screen", as: .content, using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.standup
    TimerActivityAttributes.ContentState.paused
}
