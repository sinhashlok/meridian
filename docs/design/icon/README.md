# App icon: "Now-line" (final)

Source: Claude Design canvas "Meridian — iOS Clock for Tech Workers", board
"App icon · Now-line · final" (21 Oct 2026). Claude Design drew the layers inside the
board; these SVGs were extracted from its 1024 artboard unchanged (same coordinates
and colours). Nothing in this folder is built into the app. The real icon is
`Meridian/AppIcon.icon`, made in Icon Composer from these files.

Three zones as 24-hour rows, each shifted by its offset. Work hours overlap only
between hours 10 and 14, and the orange now-line sits in the middle of that window:
the one moment that works for everyone.

## Files

| File | Fill | Mono opacity (Tinted / Clear) | Contents |
|---|---|---|---|
| `background.svg` | #1F1E1D | system | Solid bgBase, full bleed (iOS applies the mask) |
| `fg-1-quiet-hours.svg` | #B8B2A7 | 28% | 12 shapes: sleep lines (24 tall) and stretch pills (52 tall) |
| `fg-2-work-hours.svg` | #F2EFE9 | 50% | 3 work bars (96 tall), 9 hours each |
| `fg-3-now-line.svg` | #D97757 | 100% | Now-line 40×552 plus cap dot r 36 |
| `icon-1024.png` | — | — | Flat default appearance, square, no transparency (fallback only) |
| `preview-final.png` | — | — | The design board: four appearances and the size check |

Canvas 1024×1024. All shapes sit in x 170–854, y 170–788, inside the central 80%.
Row grid: 24 hours of 28.5 px; work hours row 1 07–16, row 2 10–19, row 3 05–14.

## Building `AppIcon.icon` in Icon Composer

Icon Composer ships with Xcode (Xcode › Open Developer Tool › Icon Composer).
Menu names may differ slightly between versions.

1. New icon.
2. Background: if the icon offers a background **Fill**, set it to solid `#1F1E1D`.
   Otherwise drag in `background.svg` as the bottom layer.
3. Drag in the three foreground SVGs as separate layers, bottom to top:
   `fg-1-quiet-hours`, `fg-2-work-hours`, `fg-3-now-line`.
4. Leave glass, specular and shadow on the system defaults.
5. Switch to the Mono (Tinted/Clear) appearance and set each layer's opacity:
   quiet 28%, work 50%, now-line 100%.
6. Save as **`AppIcon.icon`** in the app folder `Meridian/` (next to `Assets.xcassets`).

Then in Xcode: Meridian target › Build Settings › All › "Primary App Icon Set Name"
= `AppIcon` (Debug and Release). Build to the phone and check Light, Dark, Tinted and
Clear on the Home Screen (long-press the Home Screen › Edit › Customize).
