# Build plan

You (Shlok) own decisions, Xcode clicks and on-device testing. Claude Code (in the
terminal, inside the repo) writes and tests the code. One milestone at a time,
plan mode first, commit when tests pass.

## 0. One-time setup

Done: Xcode 27 project `Meridian` created, git initialised. Starter files,
`.gitignore` and the `MeridianCore` package scaffold are in the project folder.

Remaining Xcode clicks (select the **Meridian** project in the navigator, then the
**Meridian** target):

1. **General › Supported Destinations:** remove iPad, Mac and Apple Vision; keep
   iPhone only. (The template targets 4 platforms; AlarmKit and Live Activities are
   iPhone features, and the Mac entry is why App Sandbox settings appear.)
2. **General › Minimum Deployments:** iOS **26.0** (Xcode defaulted to 27.0;
   decision Q1 is iOS 26).
3. **Signing & Capabilities:** Team = your Apple ID (Personal Team is fine).
   Bundle Identifier = `com.shloksinha.meridian` (replaces the `devplaceholder…`
   value). Change "meridian" if you pick another name.
4. **File › Add Package Dependencies… › Add Local…** › choose the `MeridianCore`
   folder › add the `MeridianCore` library to the Meridian target.
5. Build and run once on the Simulator (⌘R), then on your iPhone.
6. **iPhone:** connect by cable, trust the Mac, turn on Developer Mode (Settings ›
   Privacy & Security). A free Apple ID's builds expire after about 7 days;
   TestFlight needs the paid Apple Developer Program.
7. Terminal, in the project folder:
   ```bash
   cd MeridianCore && swift test && cd ..        # expect 1 test passed
   git rm -r --cached --ignore-unmatch Meridian.xcodeproj/xcuserdata \
     Meridian.xcodeproj/project.xcworkspace/xcuserdata
   git add . && git commit -m "Starter docs, .gitignore, MeridianCore scaffold"
   ```
8. Start Claude Code in the project folder and give it the M0 prompt below.

Why a separate package for Core: `swift test` runs those tests on the Mac in seconds
with no simulator, like running pytest on pure functions before touching the
Spark job.

## 1. Milestones

Each milestone ends with: tests green, app runs, commit made, and a short note of
what to check on the phone.

| # | Milestone | Done when | Status |
|---|---|---|---|
| M0 | Skeleton: Tokens.swift, dark theme, 5-tab `TabView` with segmented placeholders, live UTCPill, Settings sheet stub | App runs in Simulator and on your iPhone | Done 16 Oct 2026 (`8d331aa`) |
| M0.5 | **AlarmKit spike** (throwaway branch): schedule an alarm 2 min out, lock phone, Silent on, Focus on | You saw it ring through; notes written in `docs/notes/alarmkit.md` | Done 16 Oct 2026; notes in `docs/notes/alarmkit.md` |
| M1 | Core: `ZoneClock`, `EpochParser`, `PeriodEngine` (ISO + fiscal) | All matching fixtures pass in `swift test` | Done 16 Oct 2026 (`3ac49da`) |
| M2 | Core: `CronParser` (Unix + Quartz), `ScheduleEngine` (presets + cron + gap/overlap), `OverlapEngine` | All remaining fixtures pass | Done 16 Oct 2026 (`648be8f`) |
| M3 | Zones UI: Clocks, Planner, DayPager, scrubber, BestWindowChip, Copy/Share | Planner board recreated; scrub feels right on the phone | Done 17 Oct 2026: boards matched, iPhone checks passed |
| M4 | Tools UI: Epoch, Cron, Dates, fiscal profile sheet | Boards recreated; copy buttons work | Done 17 Oct 2026 (`4f13777`); iPhone checks passed |
| M5 | Timer: duration + until, Stopwatch with laps/CSV, widget extension + Live Activity | Timers survive locking the phone | Done 17 Oct 2026; iPhone checks passed |
| M6 | Sessions: Pomodoro, meeting line, Live Activity + Dynamic Island | Session survives app kill; Island shows countdown | Done 17 Oct 2026; iPhone checks passed |
| M7 | Alarms (AlarmKit, zone + DST policy) and Jobs (list, detail, edit, reminders) | Alarm rings when locked; reminders stay within 64 | Done 17 Oct 2026; iPhone checks passed. Still to check: DST crossing (26 Oct), background refresh over days, Debug · AlarmKit |
| M8 | Widgets, Lock Screen accessories, Settings complete, accessibility pass | Tinted mode readable; VoiceOver reads Planner rows | Done 18 Oct 2026 (decisions BQ–CF); UI audits in `MeridianUITests`; iPhone checks passed |
| M9 | App icon, name, TestFlight | Build installed via TestFlight |  |

M3 is the riskiest UI (≈ 265pt track, gestures). M7 is the riskiest platform work.
Do M0.5 early so any AlarmKit surprise changes the plan before M7.

## 2. First prompts for Claude Code

**M0**
```
Read CLAUDE.md, docs/design/spec.md and docs/PLAN.md. We are on milestone M0.
Plan only: list the files you will create or change (rename the template entry
point MyApp.swift to App/MeridianApp.swift, remove the Playground code from
ContentView, Tokens.swift with every token in spec §3, the TabView shell with the 5 tabs and their segmented controls as placeholders,
a live UTCPill using TimelineView, a Settings sheet stub), and anything I must do by
hand in Xcode. Explain each new SwiftUI concept with a Python analogy. Wait for my OK.
```

**M1**
```
Milestone M1. Turn the EpochParser, ZoneClock and PeriodEngine sections of
docs/design/fixtures.md into Swift Testing tests in MeridianCore first, run
`swift test` to see them fail, then implement until they pass. MeridianCore may
import Foundation only. Show me the failing and passing test output.
```

**Every later milestone**
```
Milestone Mx. Re-read the matching sections of spec.md and fixtures.md. Plan first.
After implementing, run Core and app tests, screenshot the simulator for each
screen you built, and list what I need to verify on the iPhone.
```

## 3. Working habits

- Review every diff; ask Claude Code "explain this" for anything unclear.
- If a screen looks wrong, describe the difference against the board name
  (e.g. "PlannerScrub board: bubble should sit above the track").
- Keep decisions in `docs/decisions.md` (date, decision, why).
- When a fixture and the implementation disagree, stop and decide; never edit the
  fixture just to make a test pass.
