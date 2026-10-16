# Design boards (exported screens)

PNG exports of every phone-size board from the Claude Design canvas
"Meridian — iOS Clock for Tech Workers" (version of 16 Oct 2026, frozen after round 6).
393×852 pt at 2× (786×1704 px). Use them to compare Simulator screenshots against the design.

## How to use them

- `docs/design/spec.md` wins over these images when they disagree.
- Compare **layout, spacing, hierarchy, colour and copy**. Ignore exact glyph shapes: the
  boards were rendered on Linux, so SF Pro is replaced by Inter and SF Mono by DejaVu Sans Mono.
- Web stand-ins, not targets: the floating tab bar (use the system `TabView`), segmented
  controls, sheets, toggles and the time wheel are drawn by iOS in the real app. There is no
  status bar in the images (the top 54 pt is left empty for it).
- Sample values (dates, times, zones) are fixtures: Planner, Epoch, Cron and Sessions boards use
  Thu 15 Oct 2026 ~21:02 IST; Dates and DST boards use Fri 16 Oct 2026 15:45 IST.

## Index

| Milestone | File | Board |
|---|---|---|
| M3 Zones | [`Planner.png`](Planner.png) | Zones › Planner · no overlap, best window |
| M3 Zones | [`PlannerDST.png`](PlannerDST.png) | Zones › Planner · DST fault line |
| M3 Zones | [`PlannerScrub.png`](PlannerScrub.png) | Zones › Planner · mid-scrub |
| M3 Zones | [`PlannerLondon25h.png`](PlannerLondon25h.png) | Zones › Planner · London 25-hour day |
| M3 Zones | [`ClockChanges.png`](ClockChanges.png) | Upcoming clock changes sheet |
| M3 Zones | [`ClocksBanner.png`](ClocksBanner.png) | Zones › Clocks · warn before clocks change |
| M4 Tools | [`Epoch.png`](Epoch.png) | Tools › Epoch · 13-digit pasted |
| M4 Tools | [`EpochInvalid.png`](EpochInvalid.png) | Tools › Epoch · invalid (letter) |
| M4 Tools | [`EpochRange.png`](EpochRange.png) | Tools › Epoch · out of range |
| M4 Tools | [`EpochAmbiguous.png`](EpochAmbiguous.png) | Tools › Epoch · ambiguous 11 digits |
| M4 Tools | [`Cron.png`](Cron.png) | Tools › Cron · valid |
| M4 Tools | [`CronError.png`](CronError.png) | Tools › Cron · syntax error |
| M4 Tools | [`DatesToday.png`](DatesToday.png) | Tools › Dates · today (Fri 16 Oct 2026) |
| M4 Tools | [`DatesYearBoundary.png`](DatesYearBoundary.png) | Tools › Dates · ISO year boundary |
| M4 Tools | [`DatesReverse.png`](DatesReverse.png) | Tools › Dates · reverse lookup 2026-W44 |
| M4 Tools | [`DatesInvalid.png`](DatesInvalid.png) | Tools › Dates · invalid 2026-W54 |
| M4 Tools | [`DatesNoProfile.png`](DatesNoProfile.png) | Tools › Dates · no fiscal profile |
| M4 Tools | [`FiscalEditor.png`](FiscalEditor.png) | Fiscal profile sheet · week-based 4-4-5 |
| M4 Tools | [`EpochZoneless.png`](EpochZoneless.png) | Tools › Epoch · zone-less, repeated hour |
| M4 Tools | [`FiscalEditorMonths.png`](FiscalEditorMonths.png) | Fiscal profile sheet · calendar months |
| M5 Timer | [`TimerUntil.png`](TimerUntil.png) | Timer › Timers · duration + Until running |
| M6 Sessions | [`Sessions.png`](Sessions.png) | Sessions · running |
| M6 Sessions | [`LiveActivity.png`](LiveActivity.png) | Lock Screen · Live Activity |
| M6 Sessions | [`Island.png`](Island.png) | Dynamic Island · compact, minimal, expanded |
| M7 Alarms/Jobs | [`JobsList.png`](JobsList.png) | Alarms › Jobs · list |
| M7 Alarms/Jobs | [`JobsNotifOff.png`](JobsNotifOff.png) | Alarms › Jobs · notifications off |
| M7 Alarms/Jobs | [`JobsEmpty.png`](JobsEmpty.png) | Alarms › Jobs · empty |
| M7 Alarms/Jobs | [`JobDetail.png`](JobDetail.png) | Job detail · top |
| M7 Alarms/Jobs | [`JobDetailScrolled.png`](JobDetailScrolled.png) | Job detail · scrolled |
| M7 Alarms/Jobs | [`JobEdit.png`](JobEdit.png) | Job edit sheet · Daily preset |
| M7 Alarms/Jobs | [`JobEditCron.png`](JobEditCron.png) | Job edit sheet · Advanced cron |
| M7 Alarms/Jobs | [`AlarmsList.png`](AlarmsList.png) | Alarms · list |
| M7 Alarms/Jobs | [`AlarmEdit.png`](AlarmEdit.png) | Alarm edit sheet · keep New York time vs UTC |
| M8 Settings | [`Settings.png`](Settings.png) | Settings sheet |
| M8 Widgets | [`WidgetFull.png`](WidgetFull.png) | Medium widget · full colour |
| M8 Widgets | [`WidgetTinted.png`](WidgetTinted.png) | Medium widget · tinted |
| M8 Widgets | [`JobsWidgetFull.png`](JobsWidgetFull.png) | Jobs widgets · small + medium · full colour |
| M8 Widgets | [`JobsWidgetTinted.png`](JobsWidgetTinted.png) | Jobs widgets · small + medium · tinted |
| M8 Widgets | [`JobsLockWidgets.png`](JobsLockWidgets.png) | Jobs · Lock Screen accessory widgets |
| M8 Widgets | [`JobsWidgetLarge.png`](JobsWidgetLarge.png) | Jobs widget · large · full colour + tinted |
