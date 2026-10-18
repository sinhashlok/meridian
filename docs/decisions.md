# Decisions

Date, decision, why. Newest last.

## 16 Oct 2026 · M1

**A. Fiscal Week 1 rules (calendar-month profiles).** For dates inside their own fiscal
year the two rules always give the same week number (checked every day of FY2000–FY2099).
They differ only for the days before the year start that share its calendar week:
- *Week containing the year start:* those days are week 1 of the **next** fiscal year,
  like ISO week-years. Their fiscal year, quarter and period still follow the month.
  The result carries a week-year boundary note.
- *Week starts on the year start:* those days are the last (partial) week of the
  current fiscal year.

Example (India FY, Monday weeks): FY30 starts Sun 1 Apr 2029. Wed 28 Mar 2029 is FY29
by month; its week is FY30 W1 under "containing" and FY29 W53 under "starts on".
Why: fixtures.md asks for a test where the rules give different numbers; this is the
only reading where they can.

**B. Zone abbreviations come from a curated table in Core.** Foundation's
`TimeZone.abbreviation` depends on the device locale (on en_IN, London is `GMT+1` and
SF `GMT-7`; on en_US, Mumbai is `GMT+5:30`). Zones in the table show e.g. `BST (UTC+1)`;
zones not in it show the offset only (`UTC+4`). Why: deterministic tests and copy text,
and the offset is always shown, so a missing abbreviation loses nothing.

**C. Epoch unit detection by significant digits.** 1–10 s; 11–12 ambiguous, default
ms; 13 ms; 14–15 ambiguous, default µs; 16 µs; 17–18 ambiguous, default ns; 19 ns;
more is an error. Why: in each ambiguous band only the larger unit gives a plausible
date (12 digits as ms = 1973–2001; as seconds = year 5138+). The override always works.

**Epoch formatting uses integer calendar maths, not `Calendar`.** `GregorianDays`
(Hinnant's algorithms) converts day counts to dates. Why: Foundation's Gregorian calendar
is Julian before 15 Oct 1582, and going through `Date` would put nanoseconds in a
`Double`. Checked against every day 0001–9999 and against Foundation after 1582.
Fraction digits: omitted when zero, otherwise the unit's precision (`.800` for ms).

## 16 Oct 2026 · M2

**D. Best-window ranking: fewest asleep, then fewest in stretch, then soonest.**
Spec §4.1 says "all in work hours > fewest zones in stretch > nobody asleep > soonest".
Taken literally, Thu 15 Oct picks 08:00Z (Mumbai and London working, SF asleep: zero in
stretch), but fixtures.md expects 16:00–16:30Z "3 of 3 awake · Mumbai in stretch", and
the Mon 26 Oct row needs the same. Swapping the middle two criteria matches both rows;
all-in-work windows still rank first (none asleep, none in stretch). Why: never propose
a meeting where someone is asleep while an awake option exists. Treat as a spec wording
fix; spec.md is unchanged.

**E. Weekend skip.** A home-zone day is skipped only if every 15-minute slot in it has
some zone on its local weekend. Why: zones are on different dates; an SF-home Friday's
09:00 PDT slot is still Friday in Mumbai and must not be skipped.

**F. Every N min / Every N hours follow the wall clock**, like cron `*/N`, in the job's
zone. N must divide the hour (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30) or the day (1, 2, 3,
4, 6, 8, 12). Why: these jobs mirror real schedulers.

**G. Defaults.** Stretch = 2 h before work and 4 h after (07–09 and 18–22 for 09–18).
Work hours start and end on the same local day (night shifts later). Counts wording with
someone asleep: "2 of 3 awake · SF asleep".

**Cron details.** Unix follows Vixie cron: when both day fields are restricted a day
matching either runs; a day field starting with `*` (even `*/2`) counts as unrestricted,
so the fields AND. Quartz needs `?` in exactly one day field. "Never runs" is checked
over a full 400-year Gregorian cycle. DST: a skipped wall time runs at the next valid
time and duplicates are dropped (02:00 → 03:00 when 03:00 is also scheduled runs once);
a repeated wall time runs once, at its first occurrence.

## 16 Oct 2026 · M3

**H. Zone search data.** A curated list of ~150 cities (city, country, IANA id) lives in
Core as plain Swift data; every other IANA zone is still found by its id or city part.
Why: Foundation has no zone → country map, and Core stays dependency-free.

**I. UTC mode in Zones.** Clocks rows keep each zone's own time (that's the world
clock). The Planner switches its reference zone to UTC: the axis, ticks, scrubber,
best-window times and DayPager follow the UTC day, with a `UTC` suffix. Copy text is
unchanged (it always has a UTC line).

**J. 24-hour display in M3.** All times Meridian draws are 24-hour; "Follow system"
arrives with Settings in M8. Native `DatePicker` inputs (work hours) already follow the
system setting, so on a 12-hour phone they show AM/PM.

**K. Clocks day offsets are relative to the home zone** ("Today · −4h 30m"), matching
the Planner, not the phone's current zone.

**L. Copy/Share tags.** `early` (stretch before work), `late` (stretch after work),
`asleep`, `weekend`; nothing in work hours. The "London changes clocks on Sun 25 Oct"
note appears when a zone changes its clocks between now and the meeting (our reading
of spec §5.3 "when crossing").

## 16 Oct 2026 · M3 board review

Compared the M3 screens with boards Planner, PlannerScrub, PlannerDST, PlannerLondon25h,
ClocksBanner and ClockChanges. Where the spec and a board disagree, the spec wins.

**M. Day counts are calendar days** in the changing zone ("DST in 9d", "in 9 days"),
where the boards say 8 for Fri 16 Oct → Sun 25 Oct. Why: the boards counted whole 24-hour
periods, which would call a change tomorrow at 02:00 "in 0 days"; calendar days agree with
"today/tomorrow" and with the Sunday the user sees.

**N. Best window and meeting headline are in UTC** (`16:00–16:30 UTC`, `Mon …` when on
another day), with each zone's local time underneath. Matches the copy text's second line.

**O. Planner order is conclusion first:** DayPager, banner, best window, grid, DST notes,
Add zone, meeting card. The banner is about the viewed day ("Weekend in all 3 cities", or
"No hour works for all 3 cities" plus the first zone on its weekend or pair that never
meets), not the best window's day.

**P. Other days keep the selection and meeting card** (the DST boards leave them out);
meetings are planned for future days. With nothing picked, another day keeps the current
wall time, as paging does.

**Q. Today button always shown**, dimmed and disabled on today; the "Today" label is
dropped then. Other labels (Tomorrow, Weekend, Clocks change in …) stay.

**R. Warn-before-clocks-change banner exists now**, behind `AppState.warnsBeforeClockChanges`
(off). Settings owns the toggle from M8; `-MeridianWarn 1` shows it. It names the soonest
change within 14 days, compared with home ("you").

**S. Upcoming clock changes shows each zone's next change**, soonest first, then zones
that never change ("IST all year"). "Also used by alarms and jobs" arrives in M7.

**T. Kept against the boards:** Planner · Clocks segment order (spec §2), the visible
Edit button on Clocks, the native close button on sheets.

**U. While scrubbing**, the hint "Release to pick this time. Snaps every 15 min." replaces
Add zone and the meeting card, and row captions show the selected time and hour kind.

Row captions: today shows each zone's time now (`21:02 IST`); another day, or any day with
a clock change, shows offsets (`IST · +5:30`) or the change (`BST → GMT`). DST fault lines
and notes cover non-reference zones; the reference zone's own change gives the 23/25-hour
label (`01 BST · 01 GMT`, `01–02 skipped`), shaded repeated hour and note.

**V. Owner review of the Planner (16 Oct 2026).** The scrub bubble drops its weekday
(`22:15 IST`, not `Fri 22:15 IST`: it read like the date "Fri 22", and the grid header
already names the day) and gets a pointer to the selection line. The bubble is a fixed size: the grid card's
full width and at least two lines of counts, so it never jumps while scrubbing; only the
pointer moves. The meeting card lists
one zone per row (name, then times in one aligned column with their tags), the owner's
chosen standard over the board's three columns; zones stack at accessibility sizes. The
best-window bracket is drawn as corner caps, because a full outline beside the selection
band looked like a second selection line.

## 16 Oct 2026 · M4 Tools

**W. "Lengths we read"** (input longer than 19 digits): what the first 10/13/16/19 digits
would mean as seconds/ms/µs/ns, as dates, instead of the board's `…800000` suffixes.
Why: it answers "were two values pasted together?".

**X. Zone choices** for Interpret as (Epoch) and Evaluate in (Cron): UTC (default), this
phone's zone and saved zones. No full search in M4.

**Y. Fiscal storage.** One SwiftData row per profile (`SavedFiscalProfile`) holding the
Core `FiscalProfile` as JSON, plus active flag and order. No profile on first launch.
Presets: India FY (Apr, Mon weeks), US federal (Oct, Sun weeks), Retail 4-4-5 (Feb,
Sat nearest 31 Jan), plus Custom.

**Z. 53rd week is shown as "Last period"**, not a picker: Core supports only that rule.

**AA. Fiscal-period input**: `FY27`, `FY2026-27`, `Q3 FY27`, `P7 FY27`, any order and case,
read against the active profile. Without a profile the input asks for one.

**AB. Today and Now.** Dates' Today follows the UTC pill (spec). Epoch's Now inserts the
current epoch in the unit currently shown (seconds when empty).

**AC. Each tool remembers its last input** (and Epoch/Cron their zone) across launches.

**AD. Replace button only for look-alikes**: `O`/`o` → `0`, `l`/`I` → `1`.

**AE. Relative time** is elapsed time: just now · N min · N h M min · N days (< 60) ·
N months (< 2 years) · N years, with `ago` / `in`.

**AF. Cron key row** above the keyboard: `* , - /`, plus `? L #` for Quartz.

**AG. Fiscal list rules live in Core** (`FiscalProfileList`: max 3, exactly one active,
removing the active one activates the first), so the app still needs no test target.

Owner-review standards from M3 (decision V) applied: values in aligned rows, no
date-like strings, siblings wrap the same way.

## 17 Oct 2026 · M5 Timer

**AH. How timers ring.** Each running timer is one AlarmKit *alarm* with a `.fixed(end)`
schedule, not AlarmKit's `.timer` countdown. Pause, +1 min and resume cancel it and
schedule a new id. Why: spec §6 wants one Live Activity ("soonest large, +2 more"), not
one per timer; +1 min isn't a system action; and FB23754550 reports countdown timers
alerting silently on iOS 27.

**AI. Alarms permission denied:** a local notification at the end instead, plus one line
over the list ("Alarms are off for Meridian, so timers only notify and stay quiet in
Silent mode.") with Open Settings. Permissions are asked on the first Start.

**AJ. Finished timers stay as cards** until dismissed (Done + Restart/×; Until shows
"Passed 10 min ago"). We can't reliably learn that Stop was tapped (M0.5 test 9). Order:
done, then running by end, then paused by time left. Header counts each kind.

**AK. Remaining time** is `MM:SS`, or `HH:MM:SS` from an hour, rounded *up* (10:00 at the
start, 00:00 only at the end). The bar shows the remaining fraction (board: 67% at 6:42 of
10:00). The Live Activity uses the system countdown, which prints `6:42`.

**AL. Ends and Until lines.** "Ends 21:16 IST" in the shown zone (phone, or UTC with the
pill), weekday only when not today. A note when the shown zone changes clocks before the
end ("Clocks go back 1 hour at 02:00 BST before this ends."), unless a §5.2 note (AM)
already covers that zone. Until: "Until 02:00 UTC" + "07:30 IST on this phone · Fri",
hidden when the target zone is the shown zone.

**AM. Until in a gap or repeated hour** follows §5.2: skipped → next valid time with
"Your scheduler may differ."; repeated → First by default, First | Second shown in the
sheet only when the time repeats. If the first has passed, "Until 01:30" is the second
(the next time the clock reads 01:30).

**AN. New-timer sheet:** Duration (h/m/s wheels, max 23:59:59) or Until (time, zone menu
as decision X, UTC default, last used remembered). Empty name → "10 min" / "02:00 UTC".

**AO. Storage:** timers are SwiftData `SavedTimer` rows (Core `CountdownTimer` as JSON +
alarm id), changed only through `TimerStore`. The stopwatch is one JSON value in
`UserDefaults`. Instants and millisecond totals only, never a running counter.

**AP. Stopwatch:** `MM:SS.cc` (`H:MM:SS.cc` from an hour), centiseconds truncated, laps as
whole-ms totals (nearest ms: `Date` is a `Double`). Fastest/slowest from 3 laps, earliest
wins ties, none if all equal. CSV `lap,split_ms,total_ms,split,total`, completed laps only.

**AQ. Live Activity is display-only in M5** (Lock Screen + Island compact/minimal/expanded;
tap opens Timer via `meridian://timer`). Pause / +1 min / Stop buttons need App Intents and
come with M6's Sessions intents. Known limit: with no push server, when the soonest timer
ends in the background the activity shows 0:00 until the app is opened; the alarm rings.

**AR. Reconcile** on every change, on launch and on `scenePhase == .active`: Core's
`TimerAlarmPlan` compares stored timers with `AlarmManager.shared.alarms`. It only touches
alarm ids it scheduled for timers (`timer.alarmIDs`), because AlarmKit's list doesn't say
what an alarm is for and M7's alarms will share it. One sync runs at a time.

**AS. Widget extension** `MeridianWidgetsExtension` (folder `MeridianWidgets/`). `Shared/`
is compiled into both targets (`TimerActivityAttributes`); `Tokens.swift` is also a
member of the widget target. The content state carries Core-formatted strings, so the
widget doesn't link `MeridianCore` until M8.

## 17 Oct 2026 · M6 Sessions

**AT. A session is a list of phases with real instants**, planned at Start. Pause
records `pausedAt`; resume moves every later boundary by the pause; +5 min lengthens
the current phase and moves the rest; Skip ends it now and pulls the rest earlier.
"Where am I" is computed from `now`, so the session advances with the app killed.
Each phase keeps its paused seconds, so history never counts a pause as focus.

**AU. A session ends after the last focus** (4 focus + 3 breaks, no long break):
"Session done · 1 h 40 min focused", success haptic, then New session.

**AV. Phase ends ring with AlarmKit**, one `.fixed` alarm per boundary still ahead,
all scheduled up front ("Break · 5 min", "Focus 2 of 4", "Session done"); none while
paused. Denied Alarms falls back to notifications with the timers' note (AI).

**AW. Lengths are editable when idle**: Focus 15/25/45/50, Break 5/10/15, Cycles 1–6
(25/5/4 by default), remembered. Not editable mid-session.

**AX. Screen per board Sessions**, with "Ends 21:28 IST" (zone added, like Timer's AL).
Ring = remaining fraction; focus accent, break `textSecondary`, paused `textTertiary`.
Cycle dots: done `textSecondary`, current accent, upcoming `tintSleep`. Idle: Start
(the one orange button) above the meeting line. At accessibility sizes the ring's
caption and the Pause button move to their own rows.

**AY. Meeting line**: the best window from now (`bestWindow(notBefore: now)`), Planner
counts wording, "in N min" rounded **up** (board: 20 min 42 s → 21 min), "now",
"No shared window today" + "Next: Mon 16:00 UTC · …"; hidden under 2 zones. Tap →
Zones › Planner on that window (`AppState.plannerJump`).

**AZ. Session Live Activity** per boards LiveActivity and Island. Relevance: session
100, timers 50, so a running session owns the Dynamic Island. Same no-push limit as
timers: after a phase ends in the background it shows 0:00 until the app runs.

**BA. Live Activity buttons are `LiveActivityIntent`s** in `Shared/` (one session intent,
one timer intent, each with an action parameter; hidden from Shortcuts). iOS runs them
in the app; `LiveActivityActions` (app) applies the change and waits for alarms and the
activity; the widget target has a no-op stand-in. Session: Pause + Skip on the Lock
Screen, Pause / +5 min / Stop expanded. Timer: Pause + +1 min, plus Cancel expanded.

**BB. Storage**: the active session and lengths are JSON in `UserDefaults`
(`SessionStore`), shared with intents; finished focus is `SessionRecord` rows. One
`ModelContainer` (`AppModel.container`) for the scene and intents.

**BC. `AlarmDiff` (Core)** reconciles wanted fire dates with stored ids and what
AlarmKit reports. Dates match exactly, so store them as seconds since 2001
(`timeIntervalSinceReferenceDate`): seconds since 1970 don't round-trip, which made
every sync cancel and reschedule all alarms (caught in the AlarmKit log).
`AlarmService` (app) holds the AlarmKit and notification calls timers and sessions share.

## 17 Oct 2026 · M7 Alarms and Jobs

**BD. How alarms ring.** Local alarms (no zone: the phone's wall clock wherever it is)
are one AlarmKit `.relative` alarm, weekly or once, so they keep ringing if Meridian is
never opened. Zoned alarms (UTC or any IANA zone) are `.fixed` instants for the next
14 days (`ClockAlarm.window`), refilled on every change, launch, `.active` and (step 9)
background refresh. Core's `ClockAlarmPlan` decides per alarm, diffing with `AlarmDiff`;
a fingerprint of the settings replaces everything when an alarm changes. Rings that are
past but still listed (alerting or snoozed) are left alone. `ClockAlarms` only touches
ids it scheduled (`alarm.alarmIDs`).

**BE. Keep UTC time** stores the UTC time worked out at Save and never recomputes it.
Repeat days are read in the alarm's zone. Opening a Keep UTC alarm shows its zone's time
now (`forEditing`), so an unchanged Save gives back the same UTC time. "When clocks
change" shows only for zoned alarms whose zone changes clocks within a year
(`offersUTCChoice`). DSTNote names what moves: phone time (Keep <zone>), zone time
and/or phone time (Keep UTC), with the label as `(EST, UTC−5)` like the board.

**BF. One-off alarms** are armed for one instant (`onceAt`) on every save and switch-on,
and turn off once that has passed and AlarmKit no longer lists them.

**BG. Snooze** on by default, 9 min (Off, 5, 9, 10, 15): AlarmKit's secondary button with
`.countdown`; the widget draws the countdown (`AlarmLiveActivity`), and
`MeridianAlarmMetadata` moved to `Shared/`. Needs an iPhone check.

**BH. Sound is "Default" only.** AlarmKit plays the system sound or a bundled file; iOS
ringtones (the board's "Radar") aren't available to apps.

**BI. Zone picker** (`ZonePickerSheet`): Local (alarms only), UTC, saved zones, last 5
picked, search. Jobs default to UTC. Tools keep their menu (decision X).

**BJ. DST badge on alarm and job rows**, `DST 1 Nov`, when the item's zone and the phone's
differ and a change within 30 days moves it (`ClockMove`; the boards show it 16–17 days
ahead). Not for Local alarms, off alarms or paused jobs. Tap opens Upcoming clock changes,
which now also lists alarm and job zones.

**BK. Job reminders**: notifications for runs in the next 48 h, soonest first, at most 48
(16 of iOS's 64 left for timer and session fallbacks), ids `job-<id>-<run epoch>`.
Lead: at the run, 5, 10, 15, 30, 60 min (default 10). Debug demo launches never show
the system prompt (it covers screenshots and SpringBoard keeps it across relaunches).

**BL. Jobs wording follows the boards.** "4 jobs · times in IST"; Next line in the shown
zone ("today", weekday within a week, else date); countdown rounded up and orange under
24 h, whole days after; schedule lines reworded (`Weekly · Sun 03:00 UTC`,
`Every 4 hours · from 00:00 UTC`). Review after 90 days. Board JobDetail's "96 days ago"
is 95 (12 Jul → 15 Oct). Jobs use the M2 DST warnings, not JobEditCron's sentence.

**BM. Children**: offset = elapsed time from the parent's start, `+H:MM`, edited in 5-min
steps; expected at = next run + offset. The edit form is always in edit mode, so rows
show visible delete and ≡ drag handles (never swipe-only).

**BN. Alarms list** sorted by next ring, off alarms last; "Next: 18:30 IST today" follows
the UTC pill. Delete is in the edit sheet (visible button); no swipe-to-delete. With
Alarms denied there is no notification fallback for wake-up alarms: a banner says they
won't ring, with Open Settings.

**BO. Storage**: `SavedAlarm` (ClockAlarm JSON + scheduled ids) and `SavedJob` (Job JSON),
changed only through `AlarmStore` / `JobStore`.

**BP. AlarmKit capacity**: DEBUG Settings section "Debug · AlarmKit" with a limit test and
a relative-alarm-across-zone-change test, to run on the iPhone; results go in
`docs/notes/alarmkit.md`. If the limit is low, shrink `ClockAlarm.window`.

Owner-review standards applied: child rows in one aligned grid (siblings wrap the same
way), values never break mid-word at AX5.

## 17 Oct 2026 · M8 Settings, widgets, accessibility

Plan: `docs/notes/m8-plan.md`. Changes made while building are noted inline.

**BQ. Always 24-hour.** The spec's "24-hour time" Settings row is dropped (spec §2 note).

**BR. Widgets read a JSON snapshot** (`WidgetSnapshot`: zones, jobs, UTC mode) that the
app writes to the App Group container (`group.com.shloksinha.meridian`, both targets,
Debug and Release). Widgets compute every time with Core. The SwiftData store stays in
the app's container (moving it would mean migrating data already on the phone).

**BS. Timelines**: an entry now and one per whole minute for 2 hours, then `.atEnd`
(`WidgetText.timelineDates`). The app rewrites the snapshot 0.5 s after the last change
to zones, jobs or UTC mode, and on going to the background, then reloads widgets.
*Built:* `WidgetSyncer` watches `@Query` rows instead of `ModelContext.didSave`, which
wasn't posted for autosaves (the stores rely on autosave). Equal snapshots are compared
as values and not rewritten (JSONEncoder's key order varies). Countdowns use the Jobs
wording (decision BL), not `Text(timerInterval:)`.

**BT. Small clock widget** (no board): `UTC` header, UTC time large, UTC date, then home
city, its time and `IST (UTC+5:30)`. *Built:* the DST tag is the Clocks badge text
(`DST in 10d`, within 14 days) rather than `DST 25 Oct`.

**BU. Medium Planner widget** (board WidgetFull): home and the next 2 zones by order, the
home day with bars at 0.7 of the Planner's 26/16/4pt, the now-line, and the best window
from now on (a later day if today has none). Fewer than 2 zones: "Add a zone in
Meridian…". *Built:* names stay on one line, shrinking to 0.8 first (three rows with a
wrapped name don't fit); a zone changing clocks today shows a plain `DST` tag.

**BV. Tinted and clear**: only work bars and countdowns under 24 h are
`.widgetAccentable()`; stretch and sleep become opacity; no filled badges; backgrounds use
`containerBackground`. The now-line is orange in full colour and white (not accentable)
when tinted.

**BW. Jobs widgets** small/medium/large and **Lock Screen accessories** "Next job"
(inline/circular/rectangular) and "UTC" (inline/circular). *Built:* rows that don't fit are
dropped whole (`ViewThatFits`), never cut mid-line. The medium widget therefore shows 2 of
the board's 3 jobs: the schedule lines wrap to two lines, and the board only fits 3 by
overlapping them. The small widget drops title lines, then the schedule line.

**BX. UTC mode reaches widgets** through the snapshot (and App Group UserDefaults): Jobs
widget times and header switch to `UTC`.

**BY. Week start**: Follow locale · Monday · Sunday · Saturday. Orders weekday chips and day
lists; ISO weeks and fiscal profiles ignore it.

**BZ. Default working hours and work days** apply to new zones only, including the
first-launch seed.

**CA. Default fiscal profile** = the active profile (shared with Tools › Dates); None when
there are no profiles.

**CB. Permissions rows** show live status (✓ Allowed / Off / Allow), re-read on `.active`;
Allow asks. Open iOS Settings stays. About: Version and Time zone data (`2026c`).

**CC. Accessibility**: a UI test target runs `performAccessibilityAudit()` on every tab,
segment and main sheet; a test checks a Planner row's spoken label. Planner rows read
`PlannerZone.spokenRow` (name, home, time, kind, work hours). Each widget is one VoiceOver
element. Reduce Motion: moving animations become instant (`movingAnimation`,
`Motion.moving`), rolling digits crossfade (`numericTransition`); fades and SF Symbol
effects are unchanged.

**CD. Deep links**: `meridian://planner`, `meridian://clocks`, `meridian://jobs` (widgets)
join `timer` and `sessions` in `RootView.open`. Debug `-MeridianOpenURL` follows one 2 s
after launch, because `simctl openurl` stops at a confirmation alert.

**CE. Widget text size** (new): Dynamic Type is capped at xxLarge on Home Screen widgets
and xLarge on Lock Screen accessories. A widget can't grow, and above those sizes even one
row doesn't fit. Checked in the debug gallery at default size and AX5.

## 18 Oct 2026 · M8 iPhone review

**CF. Jobs widgets show every run the same way** (owner, from the iPhone; overrides board
JobsWidgetLarge). The large widget has no larger first run: up to five runs as identical
rows (time, title and full schedule line, countdown; children under a run). Rows are a
Grid, so the time column is as wide as the widest time (`1 Nov 10:30` stays on one line)
and every title starts at the same x, in the medium widget too. Small widget: the zone
label keeps its natural width beside the time (squeezed, `IST` showed as a sliver of dots).

**CG. The app is named Meridian** (owner, 18 Oct; closes Q8). Checked against the App
Store (US, India, UK): an app named exactly "Meridian" exists and about seven are
Meridian-named world clocks or time-zone apps, so the store name gets a suffix that sets
it apart, e.g. "Meridian: Dev Clock & Cron" (final wording in M9). The Home Screen shows
"Meridian". Bundle ID `com.shloksinha.meridian` and App Group stay. Before the first
upload: check Indian and US trademark registers for "Meridian" in software.
