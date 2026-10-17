import ActivityKit
import Foundation
import MeridianCore

/// Starts, updates and ends the one timer Live Activity (decision AQ). Called at the end
/// of every `TimerAlarms` sync, so it follows every change, launch and return to the app.
/// The content comes from Core's `TimerAlarmPlan.activity`.
///
/// Known limit (no push server): when the soonest timer ends in the background the
/// activity shows 0:00 until the app is next opened. The alarm still rings.
@MainActor enum TimerActivityController {
    static func update(_ timers: [CountdownTimer], now: Date) async {
        let current = Activity<TimerActivityAttributes>.activities
        guard let content = TimerAlarmPlan.activity(timers, now: now, display: .device) else {
            for activity in current { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let state = TimerActivityAttributes.ContentState(
            title: content.title, caption: content.caption, endDate: content.endDate,
            progressStart: content.progressStart, pausedRemaining: content.pausedRemaining,
            pausedFraction: content.pausedFraction, more: content.more)
        // Marked stale once the shown timer ends, so the system knows it's out of date.
        // Below a session's score: a running session owns the Dynamic Island.
        let activityContent = ActivityContent(state: state, staleDate: content.endDate, relevanceScore: 50)

        if let activity = current.first {
            await activity.update(activityContent)
            // Only ever one: end any extras (e.g. left over from a crash).
            for extra in current.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: TimerActivityAttributes(), content: activityContent)
        }
    }
}
