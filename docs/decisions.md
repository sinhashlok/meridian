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
already names the day) and gets a pointer to the selection line. The meeting card lists
one zone per row (name, then times in one aligned column with their tags), the owner's
chosen standard over the board's three columns; zones stack at accessibility sizes. The
best-window bracket is drawn as corner caps, because a full outline beside the selection
band looked like a second selection line.
