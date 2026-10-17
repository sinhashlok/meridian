# M8: widgets, Lock Screen accessories, complete Settings, accessibility pass

## Context
M3–M7 are built and passed on the iPhone. M8 is done when tinted widgets are readable and
VoiceOver reads the Planner rows (PLAN.md). Spec §2 (Settings), §6 (system surfaces) and
§5.3 (widgets: "Short DST tag") apply, plus six boards: Settings, WidgetFull/Tinted,
JobsWidgetFull/Tinted/Large, JobsLockWidgets.

What exists now: the widget extension (Live Activities only) **does not link
MeridianCore** and there is **no App Group**, so a widget can't read zones or jobs yet.
`AppState.isUTCMode`/`warnsBeforeClockChanges` are in-memory. `SettingsSheet` is a static
stub. Planner rows already have a basic VoiceOver label (`PlannerGrid.swift:327`).
The signing team is a free Personal Team (profiles expire in 7 days).

## Decisions (BQ–CD, recommended; reply "OK" to accept all)

- **BQ. Always 24-hour** (your answer). The "24-hour time" row is dropped and the spec
  change is recorded.
- **BR. Widgets read a JSON snapshot** that the app writes to the App Group container
  (zones, jobs, UTC mode). The widget computes times itself with Core. The SwiftData store
  stays where it is: moving it would mean migrating the data already on your phone.
- **BS. Timelines:** one entry per minute for 2 hours, then reload. The app also reloads
  widgets after every save and on going to background. Countdowns use the Jobs wording
  ("in 28 min", rounded up, decision BL), so `Text(timerInterval:)` isn't used.
- **BT. Small clock widget** (no board): UTC in big mono, then home city + time +
  `IST (UTC+5:30)`, plus a short `DST 25 Oct` tag within 14 days of a change. I'll show you
  a screenshot to approve.
- **BU. Medium Planner widget** (WidgetFull board): home zone + the next 2 zones by order,
  the home zone's whole day, the now-line, and the best window from now on (later days if
  today has none). Uses `OverlapEngine.day`/`bestWindow` and the existing counts wording.
  With fewer than 2 zones it shows "Add a zone in Meridian".
- **BV. Tinted/clear:** only work bars and countdowns under 24h are `.widgetAccentable()`.
  Stretch and sleep are drawn with opacity, there are no filled badges, and backgrounds use
  `containerBackground`. In full colour the now-line is orange (board), but it isn't
  accentable (the tinted board shows it white).
- **BW. Jobs widgets** small/medium/large and **Lock Screen accessories**: "Next job"
  inline/circular/rectangular (board), and "UTC" inline (`UTC 15:32`) + circular. The
  short schedule line is new Core text (`Every 4 hours · UTC`, `Monthly · 01:00 New York ·
  DST`); the large widget uses the full line and child rows. The medium board's
  "4 children" text overlaps the line below it, so I'll wrap it properly instead of
  copying that.
- **BX. UTC mode reaches widgets:** it is stored in App Group UserDefaults, persists
  across launches, and switches widget times and headers to `UTC`.
- **BY. Week start:** Follow locale · Monday · Sunday · Saturday. It orders the weekday
  chips (alarm repeat, job weekly, zone work days, default work days). ISO weeks and
  fiscal profiles ignore it.
- **BZ. Default working hours / work days** apply to new zones only, including the
  first-launch seed (board footer).
- **CA. Default fiscal profile** = the active profile (the same setting the Dates tab
  uses), with None allowed.
- **CB. Permissions rows** show the live status (✓ Allowed / Off / Not asked), re-read on
  `.active`. Tapping "Not asked" asks. "Open iOS Settings" is kept. **About:** Version + Time
  zone data version (useful for a dev tool).
- **CC. Accessibility:** add a UI test target. It runs `performAccessibilityAudit()` on
  every tab/segment and main sheet, and a test asserts Planner rows speak name, time, kind
  and work hours. Widgets get one combined label each. Reduce Motion is checked against
  every animation.
- **CD. Deep links:** the Planner widget opens `meridian://planner`, Jobs widgets
  `meridian://jobs`, the clock widget `meridian://clocks` (added to the existing
  `onOpenURL` in `RootView`).

## Your Xcode clicks (step 0, before code)

1. Meridian target › Signing & Capabilities › **+ Capability › App Groups** › + ›
   `group.com.shloksinha.meridian`. Repeat on **MeridianWidgetsExtension** with the same
   group ticked. **If Xcode refuses App Groups for the Personal Team, stop and tell me:
   that changes the plan.**
2. MeridianWidgetsExtension › General › Frameworks and Libraries › + › **MeridianCore**.
3. (Step 7) File › New › Target… › **UI Testing Bundle**, name `MeridianUITests`, target
   to test Meridian.

I'll check each click in `project.pbxproj` afterwards.

## Steps (one commit each; Core steps show red then green)

1. **Core settings values:** `WeekStart` + `Weekdays.ordered(from:)`, work-days summary
   (`Mon–Fri`, `Mon–Thu, Sat`), hours range `09:00–18:00`, `ZoneClock.dataVersion`.
2. **Core `WidgetSnapshot`** (Codable: zones as `PlannerZone` data + home flag + order,
   `[Job]`, `isUTCMode`). Round-trip and empty/legacy decode tests.
3. **Core `WidgetText`:** clock lines, mini-planner rows + best line, next-jobs rows,
   lock-screen texts, DST tag. Tests use the board values: Thu 15 Oct 2026 21:02 IST →
   Mumbai 21:02 / London 16:32 / SF 08:32, "Best compromise · 16:00–16:30 UTC",
   "3 of 3 awake · Mumbai in stretch"; jobs 21:30 "in 28 min", "Fri 07:30" "in 10h 28m",
   "1 Nov 10:30" "in 16 days". Plus `PlannerText.spokenRow` for VoiceOver. Values are checked
   with Python zoneinfo first.
4. **App Settings:** `Shared/SharedDefaults.swift` (group suite, keys). `AppState` keeps
   UTC mode / warn there. `SettingsSheet` is rebuilt to the board (Time · Work · Dates ·
   Clock changes · Permissions · About) with pushed pickers (`ClockTimePicker`, day list).
   `ZoneStore.seed/add` take the defaults; weekday chips follow week start.
   Screenshots vs Settings board, plus AX5.
5. **Snapshot writer:** `App/WidgetSync.swift` writes the snapshot + `reloadAllTimelines()`
   on `ModelContext.didSave`, UTC flip and `.background`. Deep links (CD).
6. **Widgets:** shared views in `Shared/WidgetViews.swift` (so the app can show them),
   `MeridianWidgets/ClockWidget.swift`, `PlannerWidget.swift`, `JobsWidget.swift`, a
   shared timeline provider, registered in `MeridianWidgetsBundle`. Debug gallery
   `-MeridianScreen widgets` (like `LiveActivityPreview`) at real sizes (small 170²,
   medium 364×170, large 364×382, accessories). Screenshots vs the 4 widget boards, plus AX5.
7. **Accessibility:** UI test target (click 3), audits + Planner label test, fixes for
   what the audit finds, Reduce Motion pass.
8. **Docs:** decisions BQ–CD, spec §2 note (24-hour row dropped), CLAUDE.md current
   state/Next up, PLAN.md status. Push once everything is green.

## Verification
- `cd MeridianCore && swift test`: all green (295 + new).
- `xcodebuild … test` with the new UI test target: audits pass.
- `scripts/shoot.sh` for Settings and the widget gallery, compared with their boards at
  default size and AX5.
- **iPhone (Release):** add each widget and Lock Screen accessory. Check full colour,
  **tinted** and **clear** modes; that UTC flip, adding a zone and editing a job update
  widgets within seconds; that tapping each widget opens the right screen; a VoiceOver
  walk of the Planner. Simulator screenshots can't prove tinted mode or VoiceOver speech.
