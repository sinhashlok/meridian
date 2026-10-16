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
