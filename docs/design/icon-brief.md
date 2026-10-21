# App icon brief (M9)

Sent to the Claude Design canvas "Meridian — iOS Clock for Tech Workers" on 18 Oct 2026.
No icon existed before M9: the app target has no icon set and the widget extension's
`AppIcon.appiconset` is Xcode's empty template.

**Delivered 21 Oct 2026: direction "Now-line"** (three zones as rows of hour bars, the
orange now-line through the one window where all their work hours overlap).

- Source layers, previews and the flat PNG: `docs/design/icon/` (see its README; not built).
- The real icon: `Meridian/AppIcon.icon` (Icon Composer), in the app target only. App
  extensions show the containing app's icon, so the widget extension needs no copy; its
  empty `AppIcon.appiconset` is unused (the first version of this note said both targets).
- Meridian target › Build Settings › Primary App Icon Set Name = `AppIcon` (Debug and
  Release). Background is the icon's solid fill `#1F1E1D`, not a `background.svg` layer.
- Builds (actool compiles it, `CFBundleIconName = AppIcon`). Next: check Light, Dark,
  Tinted and Clear on the phone's Home Screen; the Simulator can't judge the glass.

```
Design the app icon for Meridian, continuing from this canvas and its design system.

WHAT THE APP IS
Meridian replaces the iOS Clock app for developers, data engineers and remote tech
workers: world clock, alarms that keep a chosen zone's time, timers, stopwatch, a
zone-overlap Planner ("when can we all meet"), a schedule book for cron jobs, Pomodoro
sessions, and tools for epoch timestamps, cron expressions and fiscal dates.
iPhone only, dark mode only. Its promise: correct time across zones, stated honestly.

PLATFORM: iOS 26/27 "Liquid Glass" icons
The icon will be assembled in Apple's Icon Composer, which builds the Light, Dark,
Tinted and Clear appearances from layers and adds the glass highlights and shadows
itself. So design in layers, not as one flat picture:
- Canvas 1024×1024. iOS applies the rounded-square mask; keep the key shapes
  inside the central ~80%.
- One background layer: a solid colour (a subtle gradient is allowed).
- One to three foreground layers: flat vector shapes. No baked-in glass,
  shadows, bevels or texture, and no text or letters.
- It must read at 40–60 pt, and in Tinted/Clear mode, where colour is removed and
  only shape and opacity remain.

DESIGN SYSTEM RULES TO KEEP
- bgBase #1F1E1D, bgSurface #2A2926, bgElevated #35332F, textPrimary #F2EFE9,
  textSecondary #B8B2A7, accent #D97757, accentPressed #C4664A, onAccent #1F1E1D,
  tintStretch #5A4A3F, tintSleep #45423D.
- Orange (accent) means "now / on / do this". Use it for ONE focal element (for
  example a now-line, a clock hand, or the moment where zones overlap), not as a
  large fill and not for the whole icon.
- Never white on orange; anything on orange uses onAccent.
- The Planner encodes hours by bar HEIGHT (work tall, stretch medium, sleep a thin
  line). That language is a good source of motifs.

WHAT IT SHOULD SAY
Time across zones, with precision, for people who work in UTC. Possible motifs: a
meridian line, a clock face or hand, an offset or overlap of zones, a now-line
crossing bars of different heights, a cron-like tick. Avoid globe-plus-clock
clichés, terminal-prompt clichés ("> _") and an "M" monogram. It must look clearly
different from Apple's Clock icon and from the many existing "Meridian" world-clock
apps on the App Store.

PROCESS AND DELIVERABLES
1. First show 3 distinct directions. For each: the default (Dark) icon at Home
   Screen size and at 40 pt, a one-line rationale, and a rough Tinted (mono)
   version to prove it survives without colour.
2. After I pick one, refine it and deliver:
   - Layer files as SVG on the 1024×1024 canvas, named in stacking order
     (background.svg, fg-1-<name>.svg, fg-2-<name>.svg …), flat fills only,
     with the hex value of each layer listed.
   - Previews of all four appearances (Light, Dark, Tinted, Clear) on a Home
     Screen mockup next to a few system icons.
   - A flat 1024×1024 PNG of the default appearance as a fallback.
```
