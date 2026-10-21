# Meridian

A native iPhone clock app for developers, data engineers, analysts and remote tech
workers. It replaces the iOS Clock app (world clock, alarms, timers, stopwatch) and
answers the time questions a global tech worker asks: *when can we all meet, what is
this timestamp, when does this job run in my time zone, what fiscal week is it?*

<p>
  <img src="docs/screenshots/clocks.png" width="200" alt="Zones › Clocks: Mumbai, London and San Francisco with offsets and a DST badge">
  <img src="docs/screenshots/planner.png" width="200" alt="Zones › Planner: work, stretch and sleep bars for three cities, with the best compromise window">
  <img src="docs/screenshots/jobs.png" width="200" alt="Alarms › Jobs: a schedule book grouped by next run">
  <img src="docs/screenshots/cron.png" width="200" alt="Tools › Cron: an expression described in English with its next runs in UTC and local time">
</p>

## Features

- **Zones.** Clocks for any IANA zone, with `BST (UTC+1)` labels, day offsets and a
  badge 14 days before a clock change. The **Planner** lays each city's work, stretch
  and sleep hours on the home zone's real day (23, 24 or 25 hours), finds the best
  meeting window, and says plainly when no hour works for everyone.
- **Alarms.** AlarmKit alarms that ring through Silent and Focus. An alarm can keep
  another zone's time ("09:00 New York, 18:30 IST on this phone"), and you choose what
  happens when that zone's clocks change: keep its wall time or keep UTC.
- **Jobs.** A schedule book for recurring work (pipelines, notebooks, dashboards):
  presets or Unix/Quartz cron, always shown in the job's own zone, with optional
  reminders. No run status: it records when things should run, not whether they did.
- **Timer.** Countdowns by duration or "until 02:00 UTC", a stopwatch with laps and
  CSV export, Live Activities and the Dynamic Island.
- **Sessions.** Pomodoro with a meeting line from your Planner zones.
- **Tools.** Epoch converter (seconds to nanoseconds, exact), cron explainer with next
  runs, and dates: ISO weeks, day of year and configurable fiscal calendars.
- **Widgets.** Home Screen widgets (Clock, Planner, Jobs) and Lock Screen accessories
  (next job, UTC).

## Time rules

Correctness is the product, so every screen follows the same rules:

- Instants are stored as UTC `Date`s; wall-clock schedules as components plus an IANA
  zone id. Never raw offsets or abbreviations.
- Days are counted with a calendar, never as 86,400 seconds: they can be 23 or 25 hours.
- A wall time that doesn't exist (clocks went forward) moves to the next valid time
  (02:30 → 03:00); one that happens twice uses the first occurrence unless you pick the
  second. Python's `zoneinfo` gives 03:30 for the skipped case; the difference is
  intentional.
- Copied times always carry the offset: `17:00 BST (UTC+1)`, never a bare `IST` or `CST`.
- Timers and the stopwatch store start and end instants, never a running counter.

The full rules are in [spec §5](docs/design/spec.md).

## Requirements

- Xcode 27 (iOS 27 SDK)
- iPhone with iOS 26.0 or later (AlarmKit arrived in iOS 26). Portrait, dark mode.
- No third-party dependencies.

## Build and run

1. Open `Meridian.xcodeproj` and pick the **Meridian** scheme.
2. To sign with your own team: in each target's **Signing & Capabilities**, set your
   team, change the bundle id (`com.shloksinha.meridian`) and the App Group
   (`group.com.shloksinha.meridian`), which the app and widget extension share.
3. Run on a Simulator or an iPhone. For anything that judges speed, use a Release build:
   Debug is unoptimised.

Alarms, Live Activities, widgets and haptics need a real iPhone to check properly.

## Tests

```bash
# Core logic (fast, no Simulator)
cd MeridianCore && swift test

# App build and UI accessibility audits in the Simulator (~5 min)
xcodebuild -project Meridian.xcodeproj -scheme Meridian \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MeridianUITests test
```

Every verified value in [`docs/design/fixtures.md`](docs/design/fixtures.md) is a Core
test. Debug builds accept launch arguments that open any screen with a frozen clock, for
screenshots: see `Meridian/App/DebugLaunch.swift` and `scripts/shoot.sh`.

## Project layout

```
Meridian/            App target (SwiftUI, SwiftData, AlarmKit, ActivityKit)
  App/               Entry point, tab shell, settings, sync services
  DesignSystem/      Tokens.swift (colours, fonts, spacing) and shared views
  Features/          Zones, Alarms (and Jobs), Timer, Sessions, Tools
MeridianWidgets/     Widget extension: widgets and Live Activities
Shared/              Code in both the app and the widget extension
MeridianCore/        Local Swift package: all time logic, Foundation only, unit-tested
MeridianUITests/     Accessibility audits
docs/                Spec, plan, decisions, design boards, notes
```

Views never do date maths themselves: they ask `MeridianCore`, which is how "DST handled
everywhere" stays true.

## Docs

- [Product and design spec](docs/design/spec.md) (wins over the design boards)
- [Plan and milestones](docs/PLAN.md)
- [Decisions](docs/decisions.md)
- [Design boards](docs/design/boards/) and [verified fixtures](docs/design/fixtures.md)
- [AlarmKit findings](docs/notes/alarmkit.md)

## Status

Milestones M0–M8 are done and checked on an iPhone. M9 (app icon, name, TestFlight) is
in progress: the icon is in; TestFlight comes next.

## Licence

Copyright © 2026 Shlok Sinha. All rights reserved. The source is public to read; no
licence is granted to copy, modify or redistribute it.
