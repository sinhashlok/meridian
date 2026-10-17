import ActivityKit
import Foundation
import MeridianCore
import SwiftData

/// Starts, updates and ends the session Live Activity (decision AZ). Called at the end of
/// every `SessionAlarms` sync, so it follows every change, launch and return to the app.
/// Content comes from Core's `SessionActivityContent`.
///
/// Known limit (no push server), as for timers: when a phase ends in the background the
/// activity shows 0:00 until the app runs again; the phase alarm still rings.
@MainActor enum SessionActivityController {
    /// Above timers' score, so a running session owns the Dynamic Island.
    static let relevance: Double = 100

    static func update(_ session: PomodoroSession?, now: Date) async {
        let current = Activity<SessionActivityAttributes>.activities
        guard let session,
              let content = SessionActivityContent.make(session, now: now, display: .device, meeting: meetingLine(now: now))
        else {
            for activity in current { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let state = SessionActivityAttributes.ContentState(
            phase: content.phase, ends: content.ends, isFocus: content.isFocus, endDate: content.endDate,
            phaseStart: content.phaseStart, pausedRemaining: content.pausedRemaining,
            pausedFraction: content.pausedFraction, meetingTitle: content.meetingTitle,
            meetingDetail: content.meetingDetail)
        // Stale once this phase ends: the next one needs the app to run (see above).
        let activityContent = ActivityContent(state: state, staleDate: content.endDate, relevanceScore: relevance)

        if let activity = current.first {
            await activity.update(activityContent)
            for extra in current.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: SessionActivityAttributes(), content: activityContent)
        }
    }

    /// The same line the Sessions screen shows, from the saved Planner zones.
    private static func meetingLine(now: Date) -> MeetingLine? {
        let zones = (try? AppModel.container.mainContext.fetch(FetchDescriptor<SavedZone>(sortBy: [SortDescriptor(\.order)])))
            ?? []
        let home = zones.first(where: \.isHome)?.zone ?? .utc
        return MeetingLine.make(zones: zones.compactMap(\.plannerZone), home: home, now: now)
    }
}
