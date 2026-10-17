# Meridian — Product & Design Spec (v1)

Status: **frozen 16 Oct 2026**. Source: the Claude Design canvas
"Meridian — iOS Clock for Tech Workers" (rounds 1–6). Where a board and this file
disagree, this file wins. Known stale board text: the Components and IA boards still
say "Keep local time" for alarms; the correct label is "Keep <zone> time" (§4.2).

"Meridian" is a placeholder name (decision Q8 open).

---

## 1. Product

**Promise:** replaces the iOS Clock app day to day, and answers the time questions a
global tech worker asks: when can we all meet, what is this timestamp, when does
this job run in my time zone, what fiscal week is it.

**Principles**
1. 3-second rule: every feature ≤ 2 taps from launch behind a visible label. No
   long-press-only, swipe-only or shake actions.
2. Honest, never silent: no-overlap, DST changes and assumptions are stated in one
   line, never hidden.
3. Automatic DST everywhere (§5), with a "what changed" note when a result moves.
4. No run status anywhere. Jobs is a schedule book, not a monitor.

## 2. Information architecture

Header (native nav bar, inline title): **UTCPill** (leading) · tab title · gear
(trailing, opens Settings sheet).

| Tab | Segments (default first) | Content |
|---|---|---|
| Zones (globe) | Planner · Clocks | Overlap planner with DayPager and scrubber; world clock list |
| Alarms (alarm) | Alarms · Jobs | AlarmKit alarms with zones; Jobs schedule book |
| Timer (timer) | Timers · Stopwatch | Concurrent named timers (Duration or Until); stopwatch with laps |
| Sessions (scope) | — | Pomodoro ring + next meeting window |
| Tools (wrench.and.screwdriver) | Epoch · Cron · Dates | Developer and analyst utilities |

Each tab remembers its last segment. First launch: Zones › Planner with the device
zone added as home and suggestion chips (London · New York · San Francisco ·
Singapore · UTC). Permissions are requested only when first needed.

**Settings sheet:** ~~24-hour time (Follow system)~~ (dropped: the app is always 24-hour,
decision BQ) · Week start (Follow locale; used by
Planner and weekly schedules only — ISO weeks always start Monday, fiscal profiles
set their own) · Default working hours (09:00–18:00) · Default work days (Mon–Fri) ·
Default fiscal profile · Warn before clocks change (off; in-app banner only) ·
Permissions (Alarms, Notifications, link to iOS Settings) · About.

## 3. Design system

### 3.1 Colour tokens (dark only)

| Token | Hex | Use |
|---|---|---|
| bg.base | #1F1E1D | App background. Never #000 |
| bg.surface | #2A2926 | Rows, cards, planner track |
| bg.elevated | #35332F | Sheets, pressed rows, scrubber bubble, banners |
| separator | #3D3A35 | Hairlines only (decorative) |
| text.primary | #F2EFE9 | Times, titles, body |
| text.secondary | #B8B2A7 | Labels, abbreviations, inactive |
| text.tertiary | #A09A90 | Captions, ticks, placeholders |
| accent | #D97757 | Fills, ring, tab tint, icons, numerals ≥ 20pt |
| accent.text | #E8916F | Orange text under 20pt |
| accent.pressed | #C4664A | Pressed primary fill |
| onAccent | #1F1E1D | Label on orange fill (white fails contrast) |
| tint.stretch | #5A4A3F | Planner stretch hours (16pt bar) |
| tint.sleep | #45423D | Planner sleep baseline (4pt), inactive dots |
| fill.control | #55524C | Custom control outlines (Mark reviewed, Turn on) |
| status.danger | #F0708A | Destructive/blocking errors only, always with a symbol |

System-drawn on iOS (not tokens): segmented track and thumb, sheet scrim, sheet
grabber, Toggle off track, dimmed presenting view. No blue, green or yellow in the
palette. Success = checkmark glyph swap.

### 3.2 Accent discipline
Allowed: one filled primary button per viewport; active states (selected tab, Toggle
on, running progress, UTC pill in UTC mode); Planner work bars and now-line; job
countdowns within 24 hours; Live Activity / Dynamic Island progress.
Not allowed: headings, body, decorative icons, large fills, errors/warnings,
informational values (DST badge, epoch results, cron runs), the segmented thumb.
The best-window bracket is text.primary (orange on orange disappears).

### 3.3 Typography (all relative to a `Font.TextStyle`; ticking digits monospaced)

| Token | Spec | Relative to | Use |
|---|---|---|---|
| time.hero | SF Pro Display 64 Light | .largeTitle (clamp at .accessibility2) | Pomodoro, stopwatch |
| time.row | SF Pro Display 34 Regular | .largeTitle | Clock rows, alarm rows |
| title | SF Pro 22 Semibold | .title2 | Sheet titles |
| headline | SF Pro 17 Semibold | .headline | Row titles, buttons |
| body | SF Pro 17 Regular | .body | Banners, descriptions |
| sub | SF Pro 15 Regular | .subheadline | Secondary row text |
| caption | SF Pro 13 Regular | .footnote | Hints, badges |
| tick | SF Pro 11 Medium (floor) | .caption2 | Planner ticks |
| mono.body | SF Mono 17 | .body | Epoch/cron input and results |
| mono.time | SF Mono 28 Medium | .title | Timer cards, lap header |
| mono.caption | SF Mono 13 | .footnote | Lap list, cron runs, UTC pill |

At accessibility sizes, rows switch to vertical stacks (`ViewThatFits`).

### 3.4 Spacing, radius, elevation, haptics, motion
- Spacing (4pt base): 4 · 8 · 12 · 16 (screen margin) · 20 · 24 (section gap) · 32 · 40.
  Rows ≥ 56pt; tap targets ≥ 44×44.
- Radius (continuous): 4 bars · 8 chips · 12 rows/inputs · 16 cards · capsule pills.
- Elevation by lightness; one shadow for dragged objects (0 4 16, 40% black).
- Haptics (`.sensoryFeedback`): selection = scrubber hour / segment; light = UTC flip,
  lap, timer start; rigid = snap to best window; success = copied, session done;
  warning = Save/Start with invalid input only.
- Motion: 120ms press, 200ms state change, ~300ms layout (`.snappy` / `.smooth`).
  Number changes use `.contentTransition(.numericText())`. Reduce Motion → crossfade.

## 4. Features

### 4.1 Zones
- **Zone** = IANA id, display name, home flag, work hours, work days (default
  Mon–Fri, editable per zone), order. Search by city, country, abbreviation, offset.
- **Clocks:** TimezoneRow (.clock): city, `BST (UTC+1)`, time.row, day offset
  ("Today · −4h 30m"). DSTBadge ("DST in 8d") from 14 days before a change.
- **Planner:** DayPager (prev · date + caption `W42 · day 288` + label · next ·
  Today). Label priority: "Clocks change in <zone>" > "Weekend" > relative day.
  Rows (.planner) are placed by real UTC instants; axis is the reference (home) zone's
  day, so 23/25-hour days draw at true length with a skipped/repeated-hour marker.
  Encoding: work 26pt accent, stretch 16pt tint.stretch (default 07–09, 18–22),
  sleep 4pt tint.sleep. Weekend days: no work bars (stretch + sleep only).
- **Scrubber:** 15-minute snap, selection haptic per hour, fine-scrub plus visible
  −15/+15 buttons, VoiceOver adjustable (±30 min). Engages only on horizontal drags
  that start on the track; no swipe actions on planner rows. Keeps its wall time when
  the day changes; in a gap it moves to the next valid slot.
- **BestWindowChip:** ranking = all in work hours > fewest zones in stretch > nobody
  asleep > soonest. Skips days where any zone is on its weekend ("Skipping the
  weekend · Mon 26 Oct"). No overlap → InlineBanner "No hour works for all 3 cities"
  + "Best compromise".
- **Counts wording:** "3 of 3 in work hours" when all in work hours; otherwise
  "3 of 3 awake" + "Mumbai in stretch" (two: "Mumbai, SF in stretch").
- **Copy/Share text:**
  ```
  Meeting · Thu 15 Oct · 30 min
  16:00–16:30 UTC

  Mumbai         21:30 IST (UTC+5:30)  late
  London         17:00 BST (UTC+1)
  San Francisco  09:00 PDT (UTC−7)
  ```
- **UTCPill:** live `UTC 15:32:07`; tap flips display (not inputs) to UTC; in UTC
  mode accent outline and every time gets a `UTC` suffix.

### 4.2 Alarms
- AlarmKit. Row: time.row + zone tag; non-local alarms show "07:30 IST on this
  phone". Edit sheet: wheel, Time zone (Local · UTC · recents · search) with live
  local equivalent, **When clocks change: "Keep <zone> time" (default) | "Keep UTC
  time"** with a live DSTNote ("After 1 Nov this rings at 19:30 on this phone").
  The choice is hidden when the zone has no DST (UTC, Asia/Kolkata).
  Repeat, Label, Sound, Snooze. Permission off → banner + Settings row.

### 4.3 Jobs (Alarms › Jobs)
- Schedule book for recurring work. **No status, no last run, no colour dots.**
- Job: title, description, category (Pipeline · Notebook · Dashboard · Extract ·
  Other), Mirrors (optional free text, e.g. `Airflow DAG netsuite_nightly`),
  schedule, zone (default UTC), reminder (off by default, lead time), paused,
  last reviewed date, children.
- SchedulePicker presets: Every N min · Every N hours · Daily (one or more times) ·
  Weekly · Monthly (day 1–31 or Last; day 31 warns "Skips months without day 31") ·
  Cron (Unix 5-field or Quartz, via CronPreviewCard).
- Children: one level, ordered, offset = elapsed time from parent start ("+0:45"),
  copy says "expected at", never "runs after".
- List grouped Next 24 hours / Later / Paused, sorted by next run. Schedule line
  always in the job's zone ("Daily · 02:00 UTC"); Next line follows the UTC pill.
  Countdown orange only within 24h.
- Last reviewed: > 90 days → neutral banner "Check this still matches the real
  scheduler" + "Mark reviewed"; list shows a neutral "Review" tag.
- Reminders: local notifications in a rolling 48h window (64-notification limit).

### 4.4 Timer
- TimerCard **duration** (name, mono.time remaining, progress, +1 min, pause,
  cancel) and **until** ("Until 02:00 UTC · Deploy window", local equivalent, no
  progress bar, no pause; states: running, window passed, DST warning).
- Add-timer sheet: Duration | Until. Several run at once, sorted by soonest.
- Stopwatch: centiseconds, laps (split, total), fastest/slowest marked with fill +
  tag + glyph (≥ 3 laps), Copy CSV: `lap,split_ms,total_ms,split,total`.

### 4.5 Sessions
- PomodoroRing (25/5 default, 4 cycles), phase line "Focus · 1 of 4", "Ends 21:28".
  Focus ring accent, break ring text.secondary. Meeting line from Planner zones
  (Counts wording; "No shared window today"; hidden with < 2 zones).
- Live Activity and Dynamic Island (compact ring + time, minimal ring, expanded with
  Pause / +5 min / Stop). Live Activities tick in seconds and end after 8 hours.

### 4.6 Tools
- **Epoch:** smart input; auto-detect s / ms / µs / ns by digits (11–12 digits =
  ambiguous, show assumption + override); two-way (ISO 8601 → epoch); zone-less
  date-time gets InterpretAsChip (default UTC) and OccurrencePicker (First | Second)
  when that zone repeats the hour. Rows: UTC · Local · ISO 8601 · Relative · Unix s,
  each with a 44pt copy button. Native `PasteButton` (no paste prompt). Negative
  epochs valid. Errors inline with symbol.
- **Cron:** dialect Unix 5-field | Quartz 6/7-field. Accessory key row
  `* / , - ? L #`. Plain-English description, "Evaluate in" zone (default UTC),
  next 5 runs as UTC | Local, field-level errors with caret ("Field 3 ·
  day-of-month: 32 is outside 1–31"), DST warning, "never runs" state.
- **Dates:** PeriodInput accepts a date, ISO week (`2026-W44`) or fiscal period
  (`Q3 FY27`). Date rows: ISO week · ISO weekday · week range · day of year ·
  quarter (with day of quarter) · days left. Fiscal rows (active profile): fiscal
  year · quarter · period · week of FY · day of FY. Notes: ISO week-year boundary,
  week spanning two periods, 53-week years. Weeks are always written `YYYY-Www`.
  "Today" follows the UTC pill.
- **Fiscal profiles** (max 3, one active): name; year start month; basis Calendar
  months | Week-based; week starts on; Week 1 rule (week containing the year start |
  starts on the year start) for calendar months; for week-based: pattern 4-4-5 /
  4-5-4 / 5-4-4, year-end rule (last <weekday> of month | <weekday> nearest month
  end), 53rd week → last period; naming FY27 | FY2026-27; live preview.

## 5. Time & DST rules

### 5.1 Principle
Automatic, never silent. Instants (epochs, timers) never shift. Wall-clock things
(alarms, jobs, cron, until timers, planner rows) are resolved in their zone and get a
DSTNote (clock-arrow symbol, text.secondary, changed value text.primary) when a
change alters a result. Tapping a DSTBadge or DSTNote opens Upcoming clock changes.

### 5.2 Gap / overlap rule
- Skipped local time (spring forward): run at the next valid time.
- Repeated local time (fall back): first occurrence unless the user picks Second.
- Where the rule decided a result, the note ends "Your scheduler may differ."

### 5.3 Per-feature behaviour
| Feature | Automatic | User sees / chooses |
|---|---|---|
| Clocks | Offset/abbreviation switch at the instant; day offset recalculated | DSTBadge 14 days ahead; optional banner |
| Planner | Rows by UTC instants; 23/25h days at true length; best window per day | Fault line, "25-hour day", repeated/skipped hour marker |
| DayPager | Whole days in reference zone; scrubber keeps wall time | "Clocks change in London" |
| Alarms | Ring at chosen zone's wall time | Keep <zone> time / Keep UTC time + DSTNote |
| Jobs, Cron | Next runs in the job's zone with §5.2 | DSTBadge, warning naming the reading used |
| Epoch | Instants never shift; zone-less input read in Interpret-as zone | First / Second picker; gap note |
| Timers, Stopwatch, Sessions | Elapsed time, unaffected | "Ends" label updates with a note |
| Until timer | Target resolved in its zone with §5.2 | DST warning on the card |
| Dates | Date-only math; a 23/25h day is one day | — |
| Share/copy | Offset on every time | "London changes clocks on Sun 25 Oct" when crossing |
| Widgets, Live Activity | Timeline entries at transition instants | Short "DST" tag |

## 6. System surfaces
- Lock Screen Live Activity and Dynamic Island for Sessions and timers (soonest timer
  large, "+2 more").
- Home Screen widgets: small (UTC + home time), medium (3-zone mini planner),
  Jobs small/medium/large, Lock Screen accessories (UTC; next job). Must work in full
  colour, tinted and clear modes: only work bars and <24h countdowns are
  `.widgetAccentable()`; stretch/sleep drawn with opacity; background via
  `containerBackground`; no filled badges.
- Widgets read the UTC display setting through an App Group; they cannot flip it.
- Later in v1 if time allows: Control Center "Start session", App Intents
  ("Start 25-minute session", "What time is it in London").

## 7. Data model (proposal; SwiftData unless noted)
- `Zone` { id, ianaId, name, isHome, workStart, workEnd, workDays, order }
- `Alarm` { id, hour, minute, ianaId?, dstPolicy (keepZone|keepUTC), repeatDays,
  label, sound, snoozeMinutes, isOn }
- `Job` { id, title, notes, category, mirrors?, schedule (enum: everyMinutes,
  everyHours, daily[times], weekly, monthly, cron(dialect, expr)), ianaId,
  reminderLead?, isPaused, lastReviewed, children[ChildStep{name, offsetMinutes,
  order}] }
- `TimerItem` { id, name, kind (duration|until), endDate or target(time, ianaId),
  pausedRemaining? }
- `Session` history { start, end, phase } for daily totals.
- `FiscalProfile` { id, name, startMonth, basis, weekStart, week1Rule, pattern?,
  yearEndRule?, naming, isActive }
- Settings in `UserDefaults` (App Group suite so widgets can read them).

## 8. Out of v1
Run status or integrations (ADF, Airflow, Databricks), dependency graphs, Drift /
Server skew (v1.1), Calendar overlay (v1.1, opt-in), holiday markers (v1.1),
JWT/UUIDv7 decoders (v1.1), iPad, light mode, cloud sync.

## 9. Open items
- Q8 app name.
- R17: whether the Alarms tab should be labelled "Schedule" (validate in a 5-user test).
- Accent on glass: check UTC pill and tab tint legibility over the Planner on device.
