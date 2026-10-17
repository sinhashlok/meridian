import MeridianCore
import SwiftUI

/// Zones › Planner (spec §4.1), conclusion first (decision O): DayPager, the day's banner,
/// the best window, the grid with its scrubber and DST notes, then the selected meeting.
/// In UTC mode the reference is UTC (decision I); otherwise the home zone.
struct PlannerView: View {
    let zones: [SavedZone]

    @Environment(AppState.self) private var appState
    @State private var day: CivilDate? = DebugLaunch.plannerDay
    @State private var selection: Date? = DebugLaunch.plannerSelection
    @State private var meetingMinutes = 30
    @State private var isScrubbing = DebugLaunch.screen == "plannerScrub"
    @State private var isAdding = false
    @State private var snaps = 0
    @State private var cache = PlannerCache()

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            let plannerZones = zones.compactMap(\.plannerZone)    // once per frame, not per use
            let isUTC = appState.isUTCMode
            let homeSaved = zones.first(where: \.isHome)
            let reference = isUTC ? Zone.utc : (homeSaved?.zone ?? .utc)
            let referenceName = isUTC ? "UTC" : (homeSaved?.name ?? "UTC")
            let today = ZoneClock.local(now, in: reference).date
            let date = day ?? today
            let result = cache.result(date: date, today: today, reference: reference, zones: plannerZones,
                                      minutes: meetingMinutes, now: now)
            // On another day with nothing picked yet, keep the current wall time (as paging does).
            let fallback = result.day.axis.contains(now) ? now
                : Scrubber.instant(keeping: Scrubber.wallTime(of: now, in: reference), on: date, in: reference)
            let selected = Scrubber.snap(selection ?? fallback, in: result.day.axis)
            let selectedBinding = Binding(get: { selected }, set: { selection = $0 })
            let bestOnDay = result.best.flatMap { $0.day == date ? $0.window.interval : nil }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    DayPager(text: result.pager, isToday: date == today,
                             onPrevious: { go(to: date.adding(days: -1), from: selected, reference: reference) },
                             onNext: { go(to: date.adding(days: 1), from: selected, reference: reference) },
                             onToday: { day = nil; selection = nil })

                    if plannerZones.isEmpty {
                        ContentUnavailableView("No zones", systemImage: "globe",
                                               description: Text("Add a zone to plan across time zones."))
                    } else {
                        if let banner = result.day.banner {
                            InlineBanner(title: banner.title, detail: banner.detail)
                        }

                        if let best = result.best {
                            BestWindowCard(best: best, viewedDay: date,
                                           isSelected: best.day == date && best.window.interval.start == selected) {
                                day = best.day == today ? nil : best.day
                                selection = best.window.interval.start
                                snaps += 1
                            }
                        }

                        PlannerGrid(day: result.day, reference: reference, referenceName: referenceName,
                                    home: homeSaved?.plannerZone, zones: plannerZones, now: now,
                                    selection: selectedBinding, minutes: meetingMinutes,
                                    bracket: bestOnDay, isScrubbing: $isScrubbing)
                            .padding(.top, Spacing.xs)

                        let notes = [result.day.referenceChange(reference: reference, referenceName: referenceName)?.note,
                                     result.day.faultLineNote(reference: reference, referenceName: referenceName)]
                        ForEach(notes.compactMap(\.self), id: \.self) { note in
                            NoteLine(systemImage: "clock.arrow.circlepath", text: note)
                                .padding(.top, Spacing.xs)
                        }

                        if isScrubbing {
                            Text("Release to pick this time. Snaps every 15 min.")
                                .meridianFont(.sub)
                                .foregroundStyle(.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, Spacing.xs)
                        } else {
                            AddZoneButton { isAdding = true }
                            MeetingCard(selection: selectedBinding, minutes: $meetingMinutes, axis: result.day.axis,
                                        zones: plannerZones, now: now,
                                        onNow: selection == nil && day == nil ? nil : { day = nil; selection = nil })
                        }
                    }

                    if zones.count < 3, !isScrubbing {
                        Text("Suggestions")
                            .meridianFont(.caption)
                            .foregroundStyle(.textSecondary)
                        ZoneSuggestions(zones: zones)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
            }
            .scrollDisabled(isScrubbing)
            .defaultScrollAnchor(DebugLaunch.startsAtBottom ? .bottom : .top)
            .sensoryFeedback(Haptic.snap, trigger: snaps)
        }
        .sheet(isPresented: $isAdding) { AddZoneSheet(zones: zones) }
        // A window picked elsewhere (Sessions' meeting line): show its day and select it.
        .onChange(of: appState.plannerJump, initial: true) { _, jump in
            guard let jump else { return }
            day = jump.day
            selection = jump.start
            appState.plannerJump = nil
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
