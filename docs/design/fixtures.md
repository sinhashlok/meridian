# Golden test fixtures

Every row below was recomputed with Python `zoneinfo` (IANA 2026 rules) on
16 Oct 2026 and matches the design boards. Turn each group into Swift Testing
tests in `MeridianCore/Tests/MeridianCoreTests/`, one file per module.
If an implementation disagrees with a row, the implementation is wrong — unless the
row is marked *policy*, in which case discuss before changing.

Zones: IST = Asia/Kolkata, London = Europe/London, NY = America/New_York,
SF = America/Los_Angeles.

## EpochParser (`EpochParserTests.swift`)

| Input | Detected unit | UTC result |
|---|---|---|
| `0` | seconds | 1970-01-01T00:00:00Z |
| `1000000000` | seconds | 2001-09-09T01:46:40Z |
| `1792060800` | seconds | 2026-10-15T10:40:00Z (16:10 IST) |
| `1792060800000` | milliseconds (13 digits) | 2026-10-15T10:40:00Z |
| `1792888200` | seconds | 2026-10-25T00:30:00Z |
| `1792060800` read as ms (override) | milliseconds | 1970-01-21T17:47:40.800Z |
| 19-digit ns value | nanoseconds | must round-trip exactly via Int64 (no Double) |
| `-86400` | seconds | 1969-12-31T00:00:00Z (negative is valid) |
| 11–12 digits | ambiguous | flag ambiguity, default + override |

Reverse (ISO 8601 → epoch): `2026-10-15T10:40:00Z` → `1792060800`.

## ZoneClock: DST transitions 2026 (`ZoneClockTests.swift`)

| Zone | Instant (UTC) | Change |
|---|---|---|
| London | 2026-03-29T01:00Z | GMT (UTC+0) → BST (UTC+1) |
| London | 2026-10-25T01:00Z | BST → GMT (06:30 IST) |
| NY | 2026-03-08T07:00Z | EST (UTC−5) → EDT (UTC−4) |
| NY | 2026-11-01T06:00Z | EDT → EST (11:30 IST) |
| SF | 2026-03-08T10:00Z | PST (UTC−8) → PDT (UTC−7) |
| SF | 2026-11-01T09:00Z | PDT → PST (14:30 IST) |
| Mumbai | — | no changes (IST all year) |

Day lengths: London Sun 25 Oct 2026 = **25 h**; NY Sun 8 Mar 2026 = **23 h**.

## Gap / overlap rule (`ZoneClockTests.swift`)

| Local wall time | Result |
|---|---|
| NY 2026-11-01 01:30, First | 05:30Z (EDT, UTC−4) |
| NY 2026-11-01 01:30, Second | 06:30Z (EST, UTC−5) |
| London 2026-10-25 01:30, First | 00:30Z (BST) → epoch 1792888200, 06:00 IST |
| London 2026-10-25 01:30, Second | 01:30Z (GMT) |
| NY 2026-03-08 02:30 (does not exist) | **policy:** next valid time = 03:00 EDT = 07:00Z |

Note: Python `zoneinfo` resolves the non-existent 02:30 to 07:30Z (03:30 EDT).
Our policy deliberately differs; this is the "Your scheduler may differ" case.

## Conversions used across screens

| Instant / rule | Expected |
|---|---|
| 2026-10-15T16:00Z | Mumbai 21:30 IST (UTC+5:30) · London 17:00 BST (UTC+1) · SF 09:00 PDT (UTC−7) |
| 2026-10-26T16:00Z | Mumbai 21:30 IST · London 16:00 GMT (UTC+0) · SF 09:00 PDT |
| Alarm 09:00 NY, Keep NY time, Fri 16 Oct 2026 | 13:00Z = 18:30 IST |
| Same alarm, Mon 2 Nov 2026 | 14:00Z = 19:30 IST |
| Same alarm, Keep UTC time | always 13:00Z; NY time becomes 08:00 after 1 Nov |
| Job "monthly day 1, 01:00 NY", 1 Nov 2026 | 05:00Z (first occurrence; 10:30 IST) |
| Same job, 1 Dec 2026 | 06:00Z |
| Until 02:00 UTC from 2026-10-15T15:39:18Z | 10:20:42 remaining (07:30 IST Fri) |

## OverlapEngine (`OverlapEngineTests.swift`)

Zones: Mumbai (home), London, SF; work 09–18, stretch 07–09 and 18–22, Mon–Fri.

| Day | Expected |
|---|---|
| Thu 15 Oct 2026 | no all-work overlap; best compromise 16:00–16:30Z; "3 of 3 awake · Mumbai in stretch" |
| Sun 25 Oct 2026, home = London | weekend in all 3; skip to Mon 26 Oct 16:00–16:30Z; London axis 25 h |
| Week of 26–31 Oct | London–SF gap 7 h (normally 8 h) |

Mumbai work 09:00–18:00 IST = 03:30–12:30Z; SF work 09:00–18:00 PDT = 16:00–01:00Z.

## PeriodEngine — ISO (`PeriodEngineISOTests.swift`)

| Date | ISO week | Weekday | Day of year | Quarter |
|---|---|---|---|---|
| 2026-10-15 | 2026-W42 | 4 | 288 | Q4 |
| 2026-10-16 | 2026-W42 | 5 | 289 of 365 | Q4, day 16 of 92; 76 days left |
| 2025-12-29 | **2026-W01** | 1 | 363 of 365 | Q4, day 90 of 92; 2 left |
| 2027-01-01 | **2026-W53** | 5 | 1 | Q1 |
| 2026-10-25 | 2026-W43 | 7 | 298 | Q4 |

Weeks per ISO year: 2025 = 52, **2026 = 53**, 2027 = 52. `2026-W54` is invalid.
`2026-W44` = Mon 26 Oct – Sun 1 Nov 2026, days 299–305.

## PeriodEngine — fiscal (`PeriodEngineFiscalTests.swift`)

**India FY** (calendar months, starts 1 April, week starts Monday, naming FY27):
FY27 = Wed 1 Apr 2026 – Wed 31 Mar 2027, 365 days.

| Date | FY | Quarter | Period | Day of FY | Week (containing start) | Week (starts on start) |
|---|---|---|---|---|---|---|
| 2026-10-16 | FY27 | Q3 (day 16) | P7 Oct | 199 | 29 | 29 |
| 2025-12-29 | FY26 | Q3 (day 90) | P9 Dec | 273 | 40 | 40 |
| 2026-10-26 | FY27 | Q3 | P7 Oct | 209 | 31 | 31 |
| 2026-11-01 | FY27 | Q3 | P8 Nov | 215 | 31 | 31 |

Week 1 (containing start) = Mon 30 Mar – Sun 5 Apr 2026.
Week 1 (starts on start) = Wed 1 – Sun 5 Apr 2026 (5 days).
`2026-W44` straddles P7 (26–31 Oct) and P8 (1 Nov).
Add a test where the two week-1 rules give different numbers (pick a year where the
start date falls on a Sunday) — not covered by the boards.

**Retail 4-4-5** (week-based, starts February, weeks Sun–Sat, year ends on the
Saturday nearest 31 Jan, 53rd week → last period):

| Fiscal year | Start | End | Weeks |
|---|---|---|---|
| FY2025-26 | Sun 2 Feb 2025 | Sat 31 Jan 2026 | 52 |
| FY2026-27 | Sun 1 Feb 2026 | Sat 30 Jan 2027 | 52 |
| FY2027-28 | Sun 31 Jan 2027 | Sat 29 Jan 2028 | 52 |
| FY2028-29 | Sun 30 Jan 2028 | Sat 3 Feb 2029 | **53** (P12 = 6 weeks) |

2026-10-16 → Q3, P9 (Sun 27 Sep – Sat 31 Oct 2026), week 37.

## CronParser / ScheduleEngine (`CronTests.swift`)

From 2026-10-15T15:32Z, evaluated in UTC:

| Expression | Next runs (UTC) |
|---|---|
| `0 2 * * *` | Fri 16, Sat 17, Sun 18, Mon 19, Tue 20 Oct 02:00 (07:30 IST) |
| `0 2 * * 1-5` | Fri 16, Mon 19, Tue 20, Wed 21, Thu 22 Oct 02:00 |
| `30 22 * * 0` | Sun 18 Oct 22:30Z = Mon 04:00 IST |
| `0 2 32 * *` | error: field 3, day-of-month 32 outside 1–31 |
| `0 0 30 2 *` | valid syntax, never runs |

Also test: classic Unix cron ORs day-of-month and day-of-week when both are
restricted (`0 9 1 * 1` = the 1st of each month AND every Monday). Quartz numbers
weekdays SUN=1…SAT=7 and requires `?` in one of the two day fields.
