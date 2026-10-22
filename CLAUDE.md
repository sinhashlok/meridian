# CLAUDE.md — Meridian

Native iOS clock app for developers, data engineers, analysts and remote tech workers.
Full replacement for the iOS Clock app (world clock, alarms, timers, stopwatch) plus
a zone overlap Planner, Jobs (schedule book), Sessions (Pomodoro) and Tools
(Epoch, Cron, Dates).

- Product and design spec: `docs/design/spec.md` (wins over the design boards).
- Verified test values: `docs/design/fixtures.md`. Every value there must become a test.
- Milestones and order of work: `docs/PLAN.md`.

## About the developer

The owner is a data engineer (Python, PySpark, SQL) and new to Swift. When you
introduce a Swift or SwiftUI concept for the first time, explain it in one or two
lines using a Python/PySpark analogy (e.g. "`struct` with `Codable` is like a
dataclass you can serialise to JSON"). Prefer clear code over clever code.

## Stack (fixed; ask before changing)

- Built with Xcode 27 (iOS 27 SDK). Minimum deployment iOS 26.0 (AlarmKit arrived
  in 26). Any iOS 27-only API needs `if #available(iOS 27, *)` and a fallback.
  iOS 27 APIs are newer than your training data: check Apple's docs before using one.
- iPhone only, portrait, dark mode only.
- SwiftUI, Observation (`@Observable`), SwiftData, Swift Testing.
- App target keeps Xcode's defaults: Approachable Concurrency on, default actor
  isolation MainActor. `MeridianCore` uses Swift 6 language mode (strict).
  Don't change language mode or these settings without asking.
- AlarmKit (alarms and timers that ring through Silent/Focus), ActivityKit
  (Live Activities), WidgetKit, App Intents.
- No third-party dependencies without asking first. Core must stay dependency-free.

## Architecture

```
Meridian.xcodeproj
Meridian/                 App target (SwiftUI, folder-synchronized)
  App/                    MeridianApp.swift (entry point), TabView shell, settings sheet
  DesignSystem/           Tokens.swift (colors, fonts, spacing), shared views
  Features/Zones|Alarms|Timer|Sessions|Tools/
MeridianWidgets/          Widget extension: widgets + Live Activities
MeridianCore/             Local Swift package. Pure logic, fully unit-tested
  Sources/MeridianCore/   ZoneClock, EpochParser, CronParser, ScheduleEngine,
                          OverlapEngine, PeriodEngine (ISO + fiscal)
  Tests/MeridianCoreTests/
```

Rules:
1. `MeridianCore` imports Foundation only. Never SwiftUI, UIKit, AlarmKit, ActivityKit.
2. Views never call `TimeZone`, `Calendar` or do date math directly. They ask Core.
   This is how "DST handled everywhere" stays true.
3. All colors and fonts come from `DesignSystem/Tokens.swift`. No hex literals in views.
4. Use native controls: `TabView`, `Picker(.segmented)`, `.sheet`, `Toggle`,
   `DatePicker`, `PasteButton`. Never paint opaque custom bars (iOS 26 glass).
5. Do not hand-edit `project.pbxproj`. The project uses folder-synchronized groups;
   create files on disk in the right folder. If a target or capability must be added,
   stop and tell me the Xcode clicks.

## Time rules (correctness is the product)

- Store instants as `Date` (UTC). Store wall-clock schedules as components + IANA
  zone id (`"America/New_York"`). Never store raw offsets or abbreviations.
- Never add 86_400 seconds to mean "one day". Use `Calendar` with an explicit
  `timeZone` and `date(byAdding:)`. Days can be 23 or 25 hours.
- Gap/overlap rule (spec §5.2): skipped local time → next valid time
  (e.g. 02:30 on 8 Mar 2026 in New York → 03:00 EDT). Repeated local time → first
  occurrence unless the user picks Second. Implement with `Calendar.nextDate`
  matching policy `.nextTime` and repeated-time policy `.first`, and prove it with
  the fixtures. Note Python `zoneinfo` gives 03:30 for the skipped case; that
  difference is expected and documented.
- Epoch parsing uses `Int64`, not `Double`. Foundation `Date` is a `Double` and loses
  nanosecond precision, so the µs/ns result rows are formatted with integer math.
- Copied or shared times always include the offset: `17:00 BST (UTC+1)`.
  Never a bare abbreviation (IST and CST are ambiguous). UTC is written `UTC`.
- Timers, stopwatch and Pomodoro store a start/end `Date`, never a running counter.
  Display with `TimelineView` or `Text(timerInterval:)`.
- iOS keeps at most 64 pending local notifications. Job reminders use a rolling
  window (next 48h) refilled on app open and background refresh.
- AlarmKit: a "Keep New York time" alarm whose zone differs from the device zone must
  be scheduled as fixed dates and re-registered after each fire and on launch.
  M0.5 spike (`docs/notes/alarmkit.md`, iPhone 16 / iOS 27) confirmed: rings through
  lock, Silent, Focus and force-quit; `.fixed(Date)` keeps its instant across a device
  zone change. `alarmUpdates` did NOT report a stopped alarm while the app was
  suspended, so reconcile from `AlarmManager.shared.alarms` on launch and on
  `scenePhase == .active`; never trust the stream alone. `stopButton` is deprecated
  from 26.1: use `#available(iOS 26.1, *)`. Still open: `.relative` across a zone
  change, and the real `maximumLimitReached` count.

## UI rules (from the design system)

- Orange (`accent`) means "now, on, or do this": one filled orange button per screen,
  active states, Planner work bars and now-line, countdowns within 24h, Live
  Activity progress. Never for headings, errors, info values or large fills.
- Labels on orange fills use `onAccent` (dark), never white (contrast fails).
- Planner hours are encoded by bar HEIGHT first (work 26pt, stretch 16pt, sleep 4pt),
  colour second. Keep it that way; it is what survives tinted widgets and colour
  blindness.
- Every tap target ≥ 44×44 pt. Support Dynamic Type to AX5. Mono values wrap, never
  truncate.

## Current state (update as milestones land)

- M0 shell done: `App/MeridianApp.swift` (entry point, dark, accent tint),
  `App/RootView.swift` (5-tab `TabView`), `App/AppState.swift` (`@Observable`:
  `isUTCMode`, `isSettingsPresented`; in-memory until M8), `App/ScreenChrome.swift`
  (`.meridianScreen(title:)` = header with UTCPill + gear, `bgBase` background),
  `App/SettingsSheet.swift` (static stub rows), `DesignSystem/Tokens.swift`,
  `DesignSystem/UTCPill.swift`. Each tab shows segmented placeholders; segments are
  remembered via `@AppStorage("<tab>.segment")`.
- Token naming: spec `separator` is `separatorLine` (SwiftUI has a built-in
  `.separator`). The `AccentColor` asset must stay empty: giving it a colour makes
  Xcode generate a `.accent` symbol that clashes with the token.
- M1 done: `MeridianCore` has `EpochParser`, `ZoneClock` and `PeriodEngine` (54 tests,
  every EpochParser/ZoneClock/gap-overlap/conversion/PeriodEngine fixture row). Also
  `ClockFormat.utcTime`.
  - `EpochParser`: `EpochValue` = `Int64` seconds + `Int32` nanoseconds (exact);
    unit by significant digits with ambiguous bands (decision C); `parseISO8601`
    throws `.missingZone` for zone-less input (M4 wires Interpret-as).
  - `GregorianDays`: integer date maths (Foundation's Gregorian calendar is Julian
    before 1582). `floorDiv` for negatives: Swift `/` truncates toward zero.
  - `Zone` = validated IANA id. `ZoneClock.resolve` is THE gap/overlap rule
    (`nextDate` + `.nextTime`); never `Calendar.date(from:)` for wall times.
    Labels come from `ZoneAbbreviations` (decision B), offsets use U+2212 minus,
    UTC is written `UTC`.
  - `CivilDate`/`LocalDateTime`: zone-free values; day maths in whole days.
  - `PeriodEngine` (ISO) and `FiscalProfile` (calendar months or week-based;
    week-1 rules per decision A).
- M2 done: `CronExpression` (Unix + Quartz, caret errors, English description),
  `RunGenerator` (wall times → instants via `ZoneClock.resolve`; drops spring-gap
  duplicates, repeated times run once; "never runs" proven over 400 years),
  `ScheduleEngine` (Jobs presets, schedule line in the job's zone, warnings) and
  `OverlapEngine` (Planner day at true length, segments, best window, counts wording).
  97 Core tests. Every fixture row through CronParser/ScheduleEngine/OverlapEngine passes.
- M3 done: Zones › Clocks and Planner. Saved zones are SwiftData (`SavedZone`,
  changed only through `ZoneStore`, which keeps one home zone and contiguous order).
  First launch seeds the device zone. Core helpers: `ZoneCatalog` (search,
  `displayName`), day offsets, DST badges, clock-change cards, DayPager text,
  `Scrubber`, `MeetingText`. The Planner caches its day/best-window result
  (`PlannerCache`) so dragging stays cheap.
- M4 done: Tools › Epoch, Cron, Dates and the fiscal calendar sheets match their 14
  boards. Core wording in `EpochText`, `CronText`, `DatesText` (+ `FiscalEditorText`,
  `FiscalProfileList`); 182 Core tests. Shared views in `Features/Tools/ToolComponents.swift`
  (input box, copy row, problem block, placeholder, zone menu). Fiscal profiles are
  SwiftData JSON rows changed only through `FiscalStore`. Debug: `-MeridianTab tools`,
  `-MeridianTool epoch|cron|dates`, `-MeridianInput` (Cron uses `_` for spaces),
  `-MeridianZone <IANA>`, `-MeridianFiscal india|retail|none`,
  `-MeridianScreen fiscalEditor|fiscalProfiles`.
- M5 done (17 Oct 2026, decisions AH–AS): Timer › Timers and Stopwatch. Core `CountdownTimer`
  + `TimerText` (duration/Until, card wording), `Stopwatch` + `StopwatchText` (laps, CSV),
  `TimerAlarmPlan` (reconcile + Live Activity content); 216 Core tests. App: `SavedTimer`
  + `TimerStore`, `TimersView`/`TimerCard`/`NewTimerSheet`, `StopwatchView`, `TimerAlarms`
  (AlarmKit `.fixed` alarm per running timer, notification fallback, sync on change /
  launch / `.active`, only ids in `timer.alarmIDs`), `TimerActivityController`.
  Widget target `MeridianWidgetsExtension` (folder `MeridianWidgets/`, `TimerLiveActivity`);
  `Shared/` and `Tokens.swift` are in both targets. `meridian://timer` opens Timer.
  Debug: `-MeridianTimers demo|live|short`, `-MeridianStopwatch demo`,
  `-MeridianScreen newTimer|newTimerUntil`, `-timer.segment stopwatch`. Simulator
  screenshots don't show Island content; check it on the phone or in the Xcode preview.
- M6 done (17 Oct 2026, decisions AT–BC): Sessions. Core `PomodoroSession` (phases with
  instants; pause/+5/skip), `SessionText`, `MeetingLine`, `SessionActivityContent`,
  `AlarmDiff`; 242 Core tests. App: `SessionsView` (+ `PomodoroRing`, `MeetingLineCard`),
  `SessionStore` (UserDefaults JSON) + `SessionRecord` history, `SessionAlarms`,
  `SessionActivityController`; shared `AlarmService`, `AppModel.container`,
  `LiveActivityActions` (intents' real work). Widget: `SessionLiveActivity`,
  `LiveActivityParts` (countdown, progress, `LiveButton`), intents in
  `Shared/LiveActivityIntents.swift` with a widget stub. `AppState.tab` and
  `plannerJump` (meeting line → Planner). Debug: `-MeridianSession demo|paused|done|idle`;
  `-MeridianBottom 1` also works on Sessions.
- M7 done (17 Oct 2026, decisions BD–BP): Alarms and Jobs. Core `ClockAlarm` (+ `onceAt`,
  `forEditing`/`saving` for Keep UTC), `ClockAlarmPlan`, `AlarmText`, `ClockMove` (DST badge
  rule), `Job`, `JobText`, `ReminderPlan`; 295 Core tests. App: `SavedAlarm`/`AlarmStore`,
  `ClockAlarms` (Local = `.relative`, zoned = `.fixed` 14 days; own ids `alarm.alarmIDs`),
  `AlarmsView`/`AlarmRow`/`AlarmEditSheet`, `SavedJob`/`JobStore`, `JobReminders` (48 h, max 48,
  ids `job-<id>-<epoch>`), `JobsView`/`JobRow`/`JobDetailView`/`JobEditSheet`. Shared:
  `ZonePickerSheet`, `ActionHeader`, `RunTable` (Tools › Cron uses it too), widget
  `AlarmLiveActivity` (snooze countdown), `Shared/MeridianAlarmMetadata.swift`. DEBUG
  Settings › "Debug · AlarmKit" runs the limit and relative-alarm tests. Debug:
  `-MeridianAlarms demo|none`, `-MeridianJobs demo|none`, `-MeridianNotif off`,
  `-MeridianScreen alarmEdit|newAlarm|jobDetail|jobEdit|jobEditCron|newJob` (use
  `-alarms.segment jobs` for Jobs; boards' times: alarms `2026-10-16T10:15:07Z`, jobs
  `2026-10-15T15:32:07Z`). A system permission alert left unanswered stays up across
  relaunches and reinstalls in the Simulator: shut the Simulator down and boot it again.
  Background refresh: Background fetch + `BGTaskSchedulerPermittedIdentifiers`
  (`com.shloksinha.meridian.refresh`) in `Config/Meridian-Info.plist`; `BackgroundRefresh`
  is requested on every move to the background and runs both syncs.
- Live Activity layout: content views are in `Shared/LiveActivityViews.swift`; check them
  with `scripts/shoot.sh la liveActivity` (debug screen at real sizes, red outline past
  iOS's ~160pt Lock Screen height). The timer-driven ring shows as a spinner there; the
  real ring only appears on a device.
- Views get "now" from `AppState.now(timelineDate)`, never `Date.now` directly.
  Debug launch arguments for screenshots (ignored in Release): `-MeridianNow <ISO>`,
  `-MeridianZones "Asia/Kolkata=Mumbai,Europe/London=London"` (first is home),
  `-MeridianScreen clocks|planner|plannerScrub|addZone|editZone|changes`, `-MeridianUTC 1`,
  `-MeridianDay 2026-10-25`, `-MeridianSelect <ISO>`, `-MeridianBottom 1` (start scrolled
  to the bottom), `-MeridianWarn 1` (clock-change banner). `shoot.sh` passes them via
  `EXTRA="..."`.
- Gotchas: SwiftUI has its own `Transition`, so write `MeridianCore.Transition` in the
  app. Xcode 27 enforces member import visibility: import the module that defines a
  method (e.g. SwiftUI for `Array.move(fromOffsets:)`, SwiftData for `.modelContainer`).
  `@ScaledMetric` follows the text size of the view's *surroundings*: a
  `.dynamicTypeSize(...)` cap inside the same body doesn't limit it (wrap it, as
  `RoundIconButton` does). Check every changed screen at AX5 (`xcrun simctl ui booted
  content_size accessibility-extra-extra-extra-large`).
  Never put a `TimelineView` in a toolbar item: on iOS 27 it keeps the navigation bar
  re-laying out nonstop (main thread 100% busy, ~0.74 s freeze every second). `UTCPill`
  ticks with a `.task` loop instead. To find hangs: `xcrun xctrace record --template
  'Time Profiler' --instrument Hangs` on a Release build (the phone must be on a cable).
- Shared views (17 Oct cleanup): `App/SegmentedScreen.swift` (every segmented tab:
  header, picker, selection haptic; segments conform to `ScreenSegment`); DesignSystem
  `NoteLine` (also the DSTNote), `CopyButton`, `RoundIconButton`, `.buttonStyle(.pill)`,
  `RowOrStack` (row if it fits, else stacked; never ViewThatFits for that). Use these
  instead of re-drawing them.
- Design boards: `docs/design/boards/` (40 PNGs; read its README first: spec wins, fonts
  are substitutes, tab bar/segmented/sheets are system-drawn). M3 screens now match
  their six boards (16 Oct 2026, decisions M–U). Core texts for them: `PlannerText.swift`
  (banner, grid header, row captions, fault lines, 23/25-hour change, bubble, UTC ranges)
  and `ClockChanges.swift` (changes sheet cards, Clocks warning banner). 147 Core tests.
- Decisions A–AG, the integer-date choice and cron details: `docs/decisions.md`.
  Best-window ranking is decision D (fewest asleep before fewest in stretch), not the
  literal spec §4.1 order.
- Info.plist: generated by Xcode, merged with `Config/Meridian-Info.plist` (target
  setting Info.plist File) for keys that have no `INFOPLIST_KEY_*` build setting, such as
  `NSAlarmKitUsageDescription`. Xcode 27's Info tab has no "Custom iOS Target
  Properties" section: for supported keys use Build Settings, for others edit
  that file. Appearance is forced Dark via `INFOPLIST_KEY_UIUserInterfaceStyle`.
- M0.5 AlarmKit spike done; code kept only on branch `spike/alarmkit` (never merge it).
- Remote: `origin` = github.com/sinhashlok/meridian (public). `gh` CLI is logged in.
- App tests: `MeridianUITests` (UI audits, M8). No unit test target for app code.
- Code review (21 Oct): Core is fast (Planner recompute 0.15–1.3 ms, zone search 1.2 ms,
  50-job reminder plan 4.4 ms on the Mac, Release) and idle CPU is ~0% on every screen,
  so no Core algorithm rewrites; measure on the phone before any perf change. Core
  `SyncQueue` runs the timer/alarm/session/job-reminder syncs (one running, at most one
  waiting; a burst of requests shares the waiting run). New sync services use it.
  `RunGenerator` checks a day for clock changes up to the next day's start (Chile's
  midnight fall-back). `README.md` has screenshots in `docs/screenshots/` (590 px wide,
  board times; retake with `shoot.sh` + `sips --resampleWidth 590`). 326 Core tests.
  **Open:** since Xcode 27.1 the UI audits fail 3 of 7 (Alarms, Settings, Tools) with
  contrast findings on Job detail (bottom), Settings' notifications footnote and Cron's
  UTC note. The pre-review commit `ff9cdf7` fails the same way, so it isn't from the
  review; all 7 passed on 18 Oct with Xcode 27.0. Not yet judged real or audit change.

### Next up (as of 18 Oct 2026, M8 done; M9 next)

All M3–M7 iPhone checks passed on 17 Oct (Release build). Left over, all in
`docs/notes/alarmkit.md` › M7 iPhone checks:

1. On 26 Oct: Keep London vs Keep UTC alarms across Europe's 25 Oct DST change.
2. After 2–3 days without opening the app: zoned alarms and job reminders still fire.
3. Settings › Debug · AlarmKit from a Debug build: real alarm limit; `.relative` alarm
   across a device zone change.
4. **M8 done, iPhone checks passed 18 Oct** (plan: `docs/notes/m8-plan.md`; decisions
   BQ–CF in `docs/decisions.md`). 321 Core tests, 7 UI tests green (18 Oct).
   - Done: step 1 `SettingsValues.swift` (WeekStart, Weekdays summary/spoken, hours range,
     `ZoneClock.dataVersion`), step 2 `Widget/WidgetSnapshot.swift`, step 3
     `Widget/WidgetText.swift` + `PlannerZone.spokenRow`. 318 Core tests green.
   - Step 4 (Settings) done and checked against board Settings at default size and AX5
     (17 Oct): `Shared/SharedDefaults.swift` (App Group suite), `AppState` settings
     persisted with `didSet` (debug `-MeridianUTC`/`-MeridianWarn` via `DebugLaunch.flag`,
     `-MeridianScreen settings`), `SettingsSheet` rebuilt, `ZoneStore` takes `ZoneDefaults`,
     `WeekdayPicker(first:)`, `AlarmService.Permission`, `-MeridianTimers none`. Shoot it
     with `EXTRA="-MeridianTab tools -MeridianFiscal india -MeridianNotif off"`
     (`-MeridianFiscal` is applied by the Tools tab). A `Form` ignores
     `defaultScrollAnchor`, so `-MeridianBottom 1` scrolls it with `ScrollViewReader`.
     Differences from the board are system-drawn (iOS 27 title-case section headers, the
     glass close button) or decision BQ (no 24-hour row).
   - Step 0 Xcode clicks done (17 Oct): App Group on both targets, Debug and Release
     (files `Meridian/MeridianDebug.entitlements`, `MeridianWidgetsExtensionDebug.entitlements`;
     the "Debug" in the names is only Xcode's label), MeridianCore linked to the widget.
     The free Personal Team signs it: a Release device build carries the group in both
     targets' signatures and profiles.
   - Step 5 done (17 Oct): `App/WidgetSync.swift`. `WidgetSyncer` (invisible, in `RootView`'s
     background) builds the snapshot from `@Query` zones + jobs + UTC mode and writes it
     0.5 s after the last change, and on `.background`. Not `ModelContext.didSave`: it
     wasn't posted for autosaves (tested in the Simulator). Equal snapshots aren't rewritten
     (compared as values; JSONEncoder key order varies). Deep links `meridian://planner|
     clocks|jobs` in `RootView.open`. Debug `-MeridianOpenURL meridian://jobs` follows a link
     2 s after launch (`simctl openurl` stops at an "Open in Meridian?" alert nobody can
     tap). Snapshot file: `xcrun simctl get_app_container booted com.shloksinha.meridian
     group.com.shloksinha.meridian` › `widget-snapshot.json`.
   - Step 6 done (17 Oct): widgets Clock (small), Planner (medium), Jobs (S/M/L),
     accessories Next job (inline/circular/rect) and UTC (inline/circular). Views in
     `Shared/WidgetViews.swift`, extension files `MeridianWidgets/SnapshotProvider.swift`
     (one provider for all), `ClockWidget`, `PlannerWidget`, `JobsWidget`. Debug gallery
     `-MeridianScreen widgets` (`App/WidgetGallery.swift`, board sizes, full colour only):
     `EXTRA="-MeridianNotif off" scripts/shoot.sh widgets widgets 2026-10-15T15:32:07Z
     "Asia/Kolkata=Mumbai,Europe/London=London,America/Los_Angeles=San Francisco"`.
     Board data in `Shared/DemoData.swift`; bar style in `Shared/HourKind+Style.swift`;
     widget fonts are `FontToken.widget*`. Dynamic Type capped (decision CE).
     `-MeridianNotif off` no longer asks for notification permission.
   - Step 7 code done: Planner rows speak `spokenRow`; Reduce Motion helpers
     `movingAnimation`, `Motion.moving`, `numericTransition` (Tokens.swift); each widget
     is one VoiceOver element.
   - Step 7 tests done (18 Oct): target `MeridianUITests` (XCTest, in the shared Meridian
     scheme, not parallel): accessibility audits of 23 screens via launch args + Planner row
     label test; all 7 pass. Run with `-only-testing:MeridianUITests` (~5 min). Findings print
     as `AUDIT <screen> · …` (fail) or `SKIP … · no element` (don't fail). Every skip and its
     reason: `ScreenLayout` in the test and `docs/notes/m8-ui-audit.md`. Fixes it drove:
     `DesignSystem/RowOrStack.swift` replaces every ViewThatFits HStack/VStack pair (the audit
     loses text that ViewThatFits swaps; use RowOrStack for new row-or-stack layouts), Epoch
     Clear 44pt, JobRow spoken line, Cron field wraps (`ReturnEndsEditing`), best-window
     caption `kerning`, Job detail `-MeridianBottom 1`. `DebugLaunch.suppressesPermissionPrompts`:
     any `-MeridianNow` launch never shows AlarmKit/notification prompts.
     Gotchas: an unanswered permission prompt makes every later audit fail with
     "Invalid target app" (-902): reboot the Simulator and `xcrun simctl bootstatus
     "iPhone 17" -b` before testing. `xcodebuild test` can hang after "Test Suite 'All tests'"
     finishes: run it in the background, watch the log for that line, then kill it.
     Open (owner's call): Dates field at AX5 shows `2026-10-…`; wrapping showed `2026-10-1`
     on its own line, so it was left single-line (options in the audit note).
   - Step 8 done (18 Oct): decisions BQ–CE in `docs/decisions.md`, spec §2 note, PLAN.md
     M8 row, pushed.
   - iPhone review (18 Oct, decision CF): every Jobs widget run is the same row (no larger
     first run), rows are a Grid so times never wrap; small widget's zone label keeps its
     width. Planner banner counts cities ("Weekend in Mumbai", "both cities").
5. **M9** (app icon, name, open-source release). Name kept: Meridian (decision CG; store name gets a
   suffix, trademark check before upload). Icon "Now-line" done (21 Oct):
   `Meridian/AppIcon.icon` (app target only; Primary App Icon Set Name = `AppIcon`), source
   layers in `docs/design/icon/`, notes in `docs/design/icon-brief.md`. Four appearances
   checked on the phone (21 Oct).
   Release (decision CH, 22 Oct): open source under MIT, no App Store/TestFlight. Users
   build it with a free Apple ID (README › Run it yourself). Bundle ids, team and App
   Group are still hard-coded to the owner's; anyone cloning must change them.
   **In progress (22 Oct): configurable signing.** Plan approved: `Config/Signing.xcconfig`
   (`MERIDIAN_TEAM`, `MERIDIAN_ID_PREFIX`, derived `DEVELOPMENT_TEAM`, `MERIDIAN_APP_GROUP`,
   `#include? "Signing.local.xcconfig"`), gitignored local file (owner's: W4D7987B7J,
   com.shloksinha) + committed `.example`. Step 1 done (`32e3435`). Step 2 done (Xcode
   clicks, verified with `-showBuildSettings`): all 3 targets × Debug/Release are based on
   `Signing.xcconfig` (never the `.local` one: it lacks `DEVELOPMENT_TEAM`/app group and
   is gitignored), no project-level team, bundle ids `$(MERIDIAN_ID_PREFIX).meridian`,
   `.meridian.MeridianWidgets`, `.MeridianUITests`. Step 3 done: entitlements + Info.plists use
   `$(MERIDIAN_APP_GROUP)` / `$(PRODUCT_BUNDLE_IDENTIFIER)`, key `MeridianAppGroup` in both
   plists, `SharedDefaults.appGroup` and `BackgroundRefresh.identifier` read Info.plist
   (`preconditionFailure` if missing). Checked in a Simulator build's plists and `.xcent`.
   Next: step 4: `shoot.sh` reads the prefix from the xcconfigs (`BUNDLE_ID` override). Step 5:
   README install steps, decision CI. Step 6: Core tests, fresh-clone Simulator build
   (empty team), Simulator + iPhone Release build, check signed ids, push. Skip UI tests;
   don't install on the phone unless asked.

Test on the phone with a Release build (Debug is unoptimised and feels slow).

## How we work

- Start each milestone in plan mode. Propose files and steps; wait for approval.
- Core first: write the test from `fixtures.md`, see it fail, then implement.
- Small commits, one logical change each. Commit messages say what and why.
- After each milestone's tests pass, push to `origin`. Never push failing work.
- Before saying "done": run Core tests and app tests (commands below) and report
  results. For UI work, run the app in the Simulator and screenshot the screen to
  compare with the matching design board.
- Haptics, AlarmKit, Live Activities and widgets must be checked on a real iPhone;
  say so instead of claiming they work.

## Commands

```bash
# Core logic tests (fast, no simulator)
cd MeridianCore && swift test

# App + tests in the simulator (pick a device from: xcrun simctl list devices available)
xcodebuild -project Meridian.xcodeproj -scheme Meridian \
  -destination 'platform=iOS Simulator,name=<device name>' test
# UI audits only (~5 min; run in the background, see M8 step 7 gotchas)
xcodebuild ... -only-testing:MeridianUITests test

# Screenshot the booted simulator
xcrun simctl io booted screenshot /tmp/screen.png

# Relaunch in a debug state (frozen clock, chosen zones, screen) and screenshot it
scripts/shoot.sh planner planner 2026-10-15T15:32:00Z
```
