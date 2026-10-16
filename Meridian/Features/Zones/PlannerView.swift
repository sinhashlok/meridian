import MeridianCore
import SwiftUI

/// Zones › Planner (spec §4.1): DayPager, rows on the reference zone's real day, the
/// scrubber, the best window and Copy/Share. In UTC mode the reference is UTC
/// (decision I); otherwise the home zone.
struct PlannerView: View {
    let zones: [SavedZone]

    @Environment(AppState.self) private var appState
    @State private var day: CivilDate?
    @State private var selection: Date?
    @State private var meetingMinutes = 30
    @State private var snaps = 0
    @State private var cache = PlannerCache()

    private var plannerZones: [PlannerZone] { zones.compactMap(\.plannerZone) }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            let isUTC = appState.isUTCMode
            let homeSaved = zones.first(where: \.isHome)
            let reference = isUTC ? Zone.utc : (homeSaved?.zone ?? .utc)
            let referenceName = isUTC ? "UTC" : (homeSaved?.name ?? "UTC")
            let suffix = isUTC ? " UTC" : ""
            let today = ZoneClock.local(now, in: reference).date
            let date = day ?? today
            let result = cache.result(date: date, today: today, reference: reference, zones: plannerZones,
                                      minutes: meetingMinutes, now: now)
            let selected = Scrubber.snap(selection ?? now, in: result.day.axis)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    DayPager(text: result.pager, isToday: date == today,
                             onPrevious: { go(to: date.adding(days: -1), from: selected, reference: reference) },
                             onNext: { go(to: date.adding(days: 1), from: selected, reference: reference) },
                             onToday: { day = nil; selection = nil })

                    if let note = result.day.lengthNote {
                        Label(note, systemImage: "clock.arrow.circlepath")
                            .meridianFont(.caption)
                            .foregroundStyle(.textSecondary)
                    }

                    if plannerZones.isEmpty {
                        ContentUnavailableView("No zones", systemImage: "globe",
                                               description: Text("Add a zone to plan across time zones."))
                    } else {
                        PlannerGrid(day: result.day, reference: reference, now: now,
                                    selection: Binding(get: { selected }, set: { selection = $0 }),
                                    bracket: result.best.flatMap { $0.day == date ? $0.window.interval : nil },
                                    timeSuffix: suffix)

                        ScrubControls(selection: Binding(get: { selected }, set: { selection = $0 }),
                                      axis: result.day.axis, reference: reference, timeSuffix: suffix,
                                      onNow: selection == nil && day == nil ? nil : { day = nil; selection = nil })

                        if let best = result.best {
                            BestWindowSection(best: best, reference: reference, referenceName: referenceName,
                                              viewedDay: date) {
                                day = best.day == today ? nil : best.day
                                selection = best.window.interval.start
                                snaps += 1
                            }
                        }

                        MeetingActions(minutes: $meetingMinutes,
                                       text: MeetingText.make(start: selected, minutes: meetingMinutes,
                                                              zones: plannerZones, now: now))
                    }

                    if zones.count < 3 {
                        Text("Suggestions")
                            .meridianFont(.caption)
                            .foregroundStyle(.textSecondary)
                        ZoneSuggestions(zones: zones)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
            }
            .sensoryFeedback(Haptic.snap, trigger: snaps)
        }
    }

    /// Changing day keeps the scrubber's wall time; a skipped time moves to the next
    /// valid slot (spec §4.1).
    private func go(to newDay: CivilDate, from current: Date, reference: Zone) {
        let wall = Scrubber.wallTime(of: current, in: reference)
        day = newDay
        selection = Scrubber.instant(keeping: wall, on: newDay, in: reference)
    }
}

/// Remembers the last day layout and best window so dragging the scrubber doesn't
/// recompute them on every frame. A plain class: updating it never triggers a redraw.
final class PlannerCache {
    struct Key: Equatable {
        let date: CivilDate
        let today: CivilDate
        let reference: Zone
        let zones: [PlannerZone]
        let minutes: Int
        let nowMinute: Int
    }

    struct Result {
        let day: PlannerDay
        let pager: DayPagerText
        let best: BestWindow?
    }

    private var key: Key?
    private var cached: Result?

    func result(date: CivilDate, today: CivilDate, reference: Zone, zones: [PlannerZone], minutes: Int,
                now: Date) -> Result {
        let key = Key(date: date, today: today, reference: reference, zones: zones, minutes: minutes,
                      nowMinute: Int(now.timeIntervalSince1970 / 60))
        if key == self.key, let cached { return cached }
        let result = Result(
            day: OverlapEngine.day(date, home: reference, zones: zones),
            pager: OverlapEngine.pager(for: date, today: today, home: reference, zones: zones),
            best: OverlapEngine.bestWindow(from: date, home: reference, zones: zones, minutes: minutes,
                                           notBefore: date == today ? now : nil))
        self.key = key
        cached = result
        return result
    }
}
