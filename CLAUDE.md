# CLAUDE.md — Meridian (working name)

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
  `ClockFormat.utcTime` and the placeholder `CoreInfo` + smoke test.
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
  `TimerAlarmPlan` (reconcile + Live Activity content); 217 Core tests. App: `SavedTimer`
  + `TimerStore`, `TimersView`/`TimerCard`/`NewTimerSheet`, `StopwatchView`, `TimerAlarms`
  (AlarmKit `.fixed` alarm per running timer, notification fallback, sync on change /
  launch / `.active`, only ids in `timer.alarmIDs`), `TimerActivityController`.
  Widget target `MeridianWidgetsExtension` (folder `MeridianWidgets/`, `TimerLiveActivity`);
  `Shared/` and `Tokens.swift` are in both targets. `meridian://timer` opens Timer.
  Debug: `-MeridianTimers demo|live|short`, `-MeridianStopwatch demo`,
  `-MeridianScreen newTimer|newTimerUntil`, `-timer.segment stopwatch`. Simulator
  screenshots don't show Island content; check it on the phone or in the Xcode preview.
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
- No app test target yet. Add one (Xcode clicks) when the first UI logic needs tests.

### Next up (as of 17 Oct 2026)

0. M5 checks on the iPhone: a timer rings when locked, on Silent, in Focus and after
   force-quit; pause / +1 min / resume / restart reschedule (one ring, at the new time);
   Until timer rings at the right time; Live Activity on the Lock Screen and Island
   (compact, minimal, expanded) and tapping it opens Timer; haptics on start and lap;
   Copy CSV pastes into Notes; deny Alarms in Settings and check the fallback line and
   notification. Then M6 Sessions (plan first): adds App Intents, then retrofit
   Pause / +1 min / Stop onto the timer Live Activity (decision AQ).
1. M3 checks only the owner can do on the iPhone: scrub feel, hourly haptic and the
   new handle/hint, best window snap haptic and ✓ state, Copy/Share, meeting length menu,
   zone add/edit/reorder/delete, DST badge tap, VoiceOver ±30 min on the meeting time.
2. M4 checks on the iPhone: Paste (needs a real clipboard), copy buttons and haptics,
   the cron key row above the keyboard, saving/editing/deleting fiscal calendars.
3. Parked (owner's call, 16 Oct): the Planner feels laggy on an iPhone 16 in Debug; not
   yet tried without the debugger or in Release. Core work per scrub frame measured at
   ~0.1 ms, so if it's real the suspect is the whole Planner body rebuilding on every drag
   (selection state lives in `PlannerView`). Fix: redraw only grid + bubble while dragging.
4. Still open for M7 (from M0.5): do `.relative` alarms follow a device zone change, and
   what is AlarmKit's real alarm limit?

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

# Screenshot the booted simulator
xcrun simctl io booted screenshot /tmp/screen.png

# Relaunch in a debug state (frozen clock, chosen zones, screen) and screenshot it
scripts/shoot.sh planner planner 2026-10-15T15:32:00Z
```
