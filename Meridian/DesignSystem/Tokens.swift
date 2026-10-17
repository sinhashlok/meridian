import SwiftUI

// Design tokens from docs/design/spec.md §3. The only file allowed to contain hex values.
// Views use them as `.foregroundStyle(.textPrimary)`, `.meridianFont(.monoCaption)`,
// `.padding(Spacing.screenMargin)`.

// MARK: - Colour (§3.1, dark only)

extension ShapeStyle where Self == Color {
    /// App background. Never #000.
    static var bgBase: Color { Color(hex: 0x1F1E1D) }
    /// Rows, cards, planner track.
    static var bgSurface: Color { Color(hex: 0x2A2926) }
    /// Sheets, pressed rows, scrubber bubble, banners.
    static var bgElevated: Color { Color(hex: 0x35332F) }
    /// Hairlines only (decorative). Spec name `separator`; renamed because SwiftUI
    /// already has a built-in `.separator` style and the two would be ambiguous.
    static var separatorLine: Color { Color(hex: 0x3D3A35) }

    /// Times, titles, body.
    static var textPrimary: Color { Color(hex: 0xF2EFE9) }
    /// Labels, abbreviations, inactive.
    static var textSecondary: Color { Color(hex: 0xB8B2A7) }
    /// Captions, ticks, placeholders.
    static var textTertiary: Color { Color(hex: 0xA09A90) }

    /// "Now, on, or do this": fills, ring, tab tint, icons, numerals ≥ 20pt. See §3.2.
    static var accent: Color { Color(hex: 0xD97757) }
    /// Orange text under 20pt.
    static var accentText: Color { Color(hex: 0xE8916F) }
    /// Pressed primary fill.
    static var accentPressed: Color { Color(hex: 0xC4664A) }
    /// Label on an orange fill. Never white (fails contrast).
    static var onAccent: Color { Color(hex: 0x1F1E1D) }

    /// Planner stretch hours (16pt bar).
    static var tintStretch: Color { Color(hex: 0x5A4A3F) }
    /// Planner sleep baseline (4pt), inactive dots.
    static var tintSleep: Color { Color(hex: 0x45423D) }
    /// Custom control outlines (Mark reviewed, Turn on).
    static var fillControl: Color { Color(hex: 0x55524C) }
    /// Destructive/blocking errors only, always paired with a symbol.
    static var statusDanger: Color { Color(hex: 0xF0708A) }
}

private extension Color {
    /// `Color(hex: 0xD97757)`: 24-bit sRGB.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Typography (§3.3)

/// Every font scales with Dynamic Type relative to a `Font.TextStyle`.
/// Apply with `.meridianFont(.headline)`.
enum FontToken {
    /// SF Pro Display 64 Light, relative to .largeTitle, clamped at .accessibility2. Pomodoro, stopwatch.
    case timeHero
    /// SF Pro Display 34 Regular (.largeTitle). Clock rows, alarm rows.
    case timeRow
    /// SF Pro 22 Semibold (.title2). Sheet titles.
    case title
    /// SF Pro 17 Semibold (.headline). Row titles, buttons.
    case headline
    /// SF Pro 17 Regular (.body). Banners, descriptions.
    case body
    /// SF Pro 15 Regular (.subheadline). Secondary row text.
    case sub
    /// SF Pro 13 Regular (.footnote). Hints, badges.
    case caption
    /// SF Pro 11 Medium (.caption2). Planner ticks. .caption2 never goes below 11pt.
    case tick
    /// SF Mono 17 (.body). Epoch/cron input and results.
    case monoBody
    /// SF Mono 28 Medium (.title). Timer cards, lap header.
    case monoTime
    /// SF Mono 13 (.footnote). Lap list, cron runs, UTC pill.
    case monoCaption

    // Widgets (boards WidgetFull, JobsWidget*): smaller than the app, sized from the boards.
    /// SF Mono 34 Semibold (.largeTitle). Clock widget UTC, large Jobs widget's next run.
    case widgetHero
    /// SF Mono 22 Semibold (.title2). Small Jobs widget's next run.
    case widgetTime
    /// SF Pro 15 Semibold (.subheadline). Small Jobs widget title, accessory titles.
    case widgetTitle
    /// SF Pro 13 Semibold (.footnote). Planner names, job rows, best window.
    case widgetRowTitle
    /// SF Mono 13 Semibold (.footnote). Job row times.
    case widgetMono
    /// SF Pro 12 Regular (.caption). Schedule lines, counts, zone labels.
    case widgetDetail
    /// SF Mono 12 (.caption). Planner widget times, child rows.
    case widgetDetailMono
    /// SF Pro 11 Semibold (.caption2). `NEXT JOBS`, `UTC` headers.
    case widgetHeader

    /// The font for every token except `.timeHero`, whose 64pt size is not a
    /// text-style default and needs `@ScaledMetric` (see `MeridianFont`).
    /// The system uses SF Pro Display automatically at 20pt and above.
    fileprivate var standardFont: Font {
        switch self {
        case .timeHero, .timeRow: .system(.largeTitle).monospacedDigit()
        case .title: .system(.title2, weight: .semibold)
        case .headline: .system(.headline, weight: .semibold)
        case .body: .system(.body)
        case .sub: .system(.subheadline)
        case .caption: .system(.footnote)
        case .tick: .system(.caption2, weight: .medium)
        case .monoBody: .system(.body, design: .monospaced)
        case .monoTime: .system(.title, design: .monospaced, weight: .medium)
        case .monoCaption: .system(.footnote, design: .monospaced)
        case .widgetHero: .system(.largeTitle, design: .monospaced, weight: .semibold)
        case .widgetTime: .system(.title2, design: .monospaced, weight: .semibold)
        case .widgetTitle: .system(.subheadline, weight: .semibold)
        case .widgetRowTitle: .system(.footnote, weight: .semibold)
        case .widgetMono: .system(.footnote, design: .monospaced, weight: .semibold)
        case .widgetDetail: .system(.caption).monospacedDigit()
        case .widgetDetailMono: .system(.caption, design: .monospaced)
        case .widgetHeader: .system(.caption2, weight: .semibold)
        }
    }
}

extension View {
    func meridianFont(_ token: FontToken) -> some View {
        modifier(MeridianFont(token: token))
    }
}

private struct MeridianFont: ViewModifier {
    let token: FontToken

    @ViewBuilder
    func body(content: Content) -> some View {
        if token == .timeHero {
            // The clamp sits outside HeroFont so HeroFont's @ScaledMetric sees the clamped size.
            content
                .modifier(HeroFont())
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else {
            content.font(token.standardFont)
        }
    }
}

private struct HeroFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 64

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .light).monospacedDigit())
    }
}

// MARK: - Spacing (§3.4, 4pt base)

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40

    /// Leading/trailing screen margin.
    static let screenMargin: CGFloat = m
    /// Gap between sections.
    static let sectionGap: CGFloat = xl
    /// Minimum row height.
    static let minRowHeight: CGFloat = 56
    /// Minimum tap target, both axes.
    static let minTapTarget: CGFloat = 44
}

// MARK: - Radius (§3.4, continuous corners; pills use Capsule)

enum Radius {
    static let bar: CGFloat = 4
    static let chip: CGFloat = 8
    static let row: CGFloat = 12
    static let card: CGFloat = 16
}

// MARK: - Elevation (§3.4)

extension View {
    /// The one shadow, for dragged objects only: 0 4 16, 40% black.
    /// SwiftUI's `radius` is about half a CSS blur, so blur 16 → radius 8.
    func dragShadow() -> some View {
        shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Motion (§3.4)

/// Number changes use `.numericTransition()`. Reduce Motion: movement becomes instant
/// (`movingAnimation`, `Motion.moving`) and rolling digits crossfade.
enum Motion {
    /// Press feedback, 120ms.
    static let press: Animation = .easeOut(duration: 0.12)
    /// State change, 200ms.
    static let stateChange: Animation = .easeInOut(duration: 0.2)
    /// Layout change, ~300ms.
    static let layout: Animation = .snappy(duration: 0.3)
    /// Layout change where a softer settle reads better.
    static let layoutSmooth: Animation = .smooth(duration: 0.3)

    /// `animation`, or none under Reduce Motion: for changes that move, slide or scale
    /// things (rows reordering, fields appearing). Colour and opacity fades don't need it.
    /// Read `@Environment(\.accessibilityReduceMotion)` in the view and pass it in.
    static func moving(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

extension View {
    /// `.animation(_:value:)` for movement: none under Reduce Motion.
    func movingAnimation(_ animation: Animation, value: some Equatable) -> some View {
        modifier(MovingAnimation(animation: animation, value: value))
    }

    /// Digits roll when a number changes; under Reduce Motion they crossfade.
    func numericTransition(countsDown: Bool = false) -> some View {
        modifier(NumericTransition(countsDown: countsDown))
    }
}

private struct MovingAnimation<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(Motion.moving(animation, reduceMotion: reduceMotion), value: value)
    }
}

private struct NumericTransition: ViewModifier {
    let countsDown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .opacity : .numericText(countsDown: countsDown))
    }
}

// MARK: - Haptics (§3.4, used with `.sensoryFeedback`)

enum Haptic {
    /// Scrubber hour, segment change.
    static let selection: SensoryFeedback = .selection
    /// UTC pill flip.
    static let utcFlip: SensoryFeedback = .impact(weight: .light)
    /// Stopwatch lap.
    static let lap: SensoryFeedback = .impact(weight: .light)
    /// Timer start.
    static let timerStart: SensoryFeedback = .impact(weight: .light)
    /// Snap to best window.
    static let snap: SensoryFeedback = .impact(flexibility: .rigid)
    /// Copied, session done.
    static let success: SensoryFeedback = .success
    /// Save/Start with invalid input only.
    static let warning: SensoryFeedback = .warning
}
