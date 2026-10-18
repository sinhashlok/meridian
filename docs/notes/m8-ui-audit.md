# M8 step 7: UI accessibility audits (18 Oct 2026)

`MeridianUITests` runs `performAccessibilityAudit()` on 23 screens (launch arguments put
each in the boards' state) plus the Planner row VoiceOver test. Run 1 failed Alarms,
Settings, Timer and Tools and didn't finish. This note records what was fixed and why
each remaining skip is the audit's blind spot, not the app's.

## Fixed in the app

- **`ViewThatFits` → `RowOrStack`** (`DesignSystem/RowOrStack.swift`). Most "Dynamic Type
  partially unsupported" hits (ActionHeader, AlarmRow, TimerCard, Stopwatch laps header,
  Epoch, Cron, Dates copy rows, Job detail) were text inside `ViewThatFits`. It keeps two
  copies of the views and swaps them as text grows, so the audit loses the element.
  `RowOrStack` is a `Layout` over one set of children: a row when they fit at natural width,
  stacked otherwise. Converted every HStack/VStack pair, plus TimezoneRow, MeetingControls
  and the Cron header (which broke "Expres-sion" at AX5). Job detail's "Next run" uses the
  `isAccessibilitySize` + `AnyLayout` pattern instead: its value aligns trailing in a row,
  leading when stacked. Not converted: WeekdayPicker (HStack vs FlowLayout) and the widgets'
  vertical ViewThatFits (they drop rows on purpose).
- **Epoch Clear button**: the 44pt frame sat outside the `Button`, so only the 20pt glyph
  was tappable. The frame is now inside the label.
- **JobRow next line**: spoken as "Next 21:30 IST today, in 28 min". The inline clock glyph
  added "Clock" to the label, and the audit read the longer label as clipped text.
- **Cron field wraps** (`axis: .vertical`, like Epoch); Return ends editing
  (`ReturnEndsEditing` drops newlines). Has an accessibility label.
- **Best-window caption** uses `kerning` instead of `tracking`, which the clipping check
  misread.
- **Job detail `-MeridianBottom 1`** scrolls by id after the push: `defaultScrollAnchor`
  settled before the tab bar inset was known and left the last rows under the bar.

## Skipped in the test (`ScreenLayout.ignores`)

- `timeHero` text: @ScaledMetric, which the Dynamic Type check can't see.
- Contrast for elements cut by the screen edge, under a tab/navigation bar, or within 32pt
  of one (iOS 26 scroll-edge fade). The bars' own contents (UTC pill, gear) are still checked.
- System glass toolbar buttons (Cancel, Save, Start, Edit, Done) inside navigation bars.
- Contrast on disabled controls (WCAG 1.4.3 exempts them): Planner's Now when at now,
  Add zone's already-added suggestion.
- `listRows`: List/Form rows, headers and footers checked at default size and AX5 that
  the checks still flag (Label, At, Time, Job edit footer, Default fiscal profile, Open iOS
  Settings, Work days, Home zone, Clocks' Add zone footer).
- Text clipping on the system search field and single-line text fields (Dates).
- Findings with no element print as `SKIP` and don't fail. Traced: hidden text spoken
  another way (Planner bubble, hour ticks, now-line; Stopwatch "Split · Total"), system
  pickers (time wheel, Settings), and contrast on Form/scroll-edge pixels. Every text token
  passes 4.5:1 on every background (lowest: tertiary on elevated, 4.51).

## Open

- Dates field at AX5 shows `2026-10-…` (single line, unchanged from M4). Wrapping it was
  tried and rejected: it showed `2026-10-1` on its own line, which reads as another date.
  Options: cap its text size, a smaller mono token at accessibility sizes, or leave it.
