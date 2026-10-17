import MeridianCore
import SwiftUI
import WidgetKit

// Home Screen widget and Lock Screen accessory content (spec §6; boards WidgetFull/Tinted,
// JobsWidgetFull/Tinted/Large, JobsLockWidgets). In Shared/ so the widget extension draws
// them and the app's debug gallery (`-MeridianScreen widgets`) shows them at real sizes.
// Every text comes from Core's `WidgetText`; these views only lay it out.
//
// Tinted and clear Home Screens (decision BV): only work bars and countdowns under 24 hours
// are `.widgetAccentable()`; stretch and sleep become opacity, and nothing is a filled badge.
// Rows that don't fit are dropped whole (`ViewThatFits`), so nothing is cut mid-line.
// Text follows Dynamic Type up to a cap (decision CE): a widget can't grow, and past
// xxLarge (xLarge on the Lock Screen) its content no longer fits.

// VoiceOver reads each widget as one element (decision CC).

extension View {
    /// Home Screen widgets: Dynamic Type up to xxLarge, read as one VoiceOver element.
    func homeWidgetStyle() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge).accessibilityElement(children: .combine)
    }
    /// Lock Screen accessories: Dynamic Type up to xLarge.
    func accessoryTypeSize() -> some View { dynamicTypeSize(...DynamicTypeSize.xLarge) }
}

// MARK: - Parts

/// `NEXT JOBS` … `IST`.
private struct WidgetHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title).textCase(.uppercase).tracking(0.6)
            Spacer(minLength: Spacing.xs)
            if let trailing { Text(trailing) }
        }
        .meridianFont(.widgetHeader)
        .foregroundStyle(.textSecondary)
    }
}

/// `⏱ in 28 min`: orange and accentable within 24 hours (§3.2, decision BV), else plain.
struct WidgetCountdown: View {
    let text: String
    let isSoon: Bool

    var body: some View {
        if isSoon {
            Text("\(Image(systemName: "clock")) \(text)")
                .foregroundStyle(.accentText)
                .widgetAccentable()
        } else {
            Text(text).foregroundStyle(.textSecondary)
        }
    }
}

/// A run's day and time: `21:30`, `Fri 07:30`, `1 Nov 10:30`.
private func dayTime(_ row: JobWidgetRow) -> String {
    row.day.map { "\($0) \(row.time)" } ?? row.time
}

/// A centred message for a widget with nothing to show.
private struct WidgetMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .meridianFont(.widgetRowTitle)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Clock (small, decision BT)

/// UTC large, then the home city's time and label.
struct ClockWidgetView: View {
    let text: ClockWidgetText

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(title: "UTC")
            Text(text.utcTime)
                .meridianFont(.widgetHero)
                .foregroundStyle(.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(text.utcDate)
                .meridianFont(.widgetDetail)
                .foregroundStyle(.textSecondary)
            Spacer(minLength: Spacing.xs)
            if let home = text.home {
                Text(home.name)
                    .meridianFont(.widgetRowTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Text(home.time)
                    .meridianFont(.widgetTime)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(home.dstBadge.map { "\(home.label) · \($0)" } ?? home.label)
                    .meridianFont(.widgetDetail)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeWidgetStyle()
    }
}

// MARK: - Planner (medium, board WidgetFull, decision BU)

struct PlannerWidgetView: View {
    /// `nil` with fewer than 2 zones.
    let text: PlannerWidgetText?

    var body: some View {
        content.homeWidgetStyle()
    }

    @ViewBuilder private var content: some View {
        if let text {
            // At large text sizes the counts line goes first, then the best window.
            ViewThatFits(in: .vertical) {
                layout(text, showsBest: true, showsCounts: true)
                layout(text, showsBest: true, showsCounts: false)
                layout(text, showsBest: false, showsCounts: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                WidgetHeader(title: "Planner")
                WidgetMessage(text: "Add a zone in Meridian to see your hours side by side.")
            }
        }
    }

    private func layout(_ text: PlannerWidgetText, showsBest: Bool, showsCounts: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PlannerWidgetRows(rows: text.rows, now: text.now)
            if showsBest {
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        if let time = text.bestTime {
                            Text("\(text.bestTitle) · \(Text(time).monospaced())")
                        } else {
                            Text(text.bestTitle)
                        }
                    }
                    .meridianFont(.widgetRowTitle)
                    .foregroundStyle(.textPrimary)
                    if showsCounts, let counts = text.counts {
                        Text(counts)
                            .meridianFont(.widgetDetail)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Name and time, then the day's bars; the now-line crosses every row.
private struct PlannerWidgetRows: View {
    let rows: [PlannerWidgetText.Row]
    let now: Double
    @Environment(\.widgetRenderingMode) private var renderingMode

    private static let nameWidth: CGFloat = 84
    private static let gap: CGFloat = Spacing.xs

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: Self.gap) {
                    label(rows[index])
                    PlannerWidgetTrack(bars: rows[index].bars)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                let track = geometry.size.width - Self.nameWidth - Self.gap
                nowLine
                    .frame(height: geometry.size.height + 4)
                    .offset(x: Self.nameWidth + Self.gap + track * now - 4, y: -4)
            }
        }
    }

    private func label(_ row: PlannerWidgetText.Row) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // One line, shrinking a little first: three rows with a wrapped name don't fit.
            Text(row.name)
                .meridianFont(.widgetRowTitle)
                .foregroundStyle(.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.8)
            HStack(spacing: Spacing.xxs) {
                Text(row.time).meridianFont(.widgetDetailMono)
                // The short DST tag (spec §5.3): this zone changes clocks today.
                if row.changesClocks { Text("DST").meridianFont(.widgetHeader) }
            }
            .foregroundStyle(.textSecondary)
        }
        .frame(width: Self.nameWidth, alignment: .leading)
    }

    /// Orange in full colour; white and not accentable when tinted (board WidgetTinted).
    private var nowLine: some View {
        let color: Color = renderingMode == .fullColor ? .accent : .textPrimary
        return VStack(spacing: 0) {
            Circle().fill(color).frame(width: 8, height: 8)
            Rectangle().fill(color).frame(width: 2)
        }
        .frame(width: 8)
    }
}

/// One row's bars, height first (work, stretch, sleep at 0.7 of the Planner's 26/16/4pt).
private struct PlannerWidgetTrack: View {
    let bars: [PlannerWidgetText.Bar]
    @Environment(\.widgetRenderingMode) private var renderingMode

    private static let scale: CGFloat = 0.7

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                ForEach(bars.indices, id: \.self) { index in
                    let bar = bars[index]
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(bar.kind))
                        .frame(width: max(CGFloat(bar.end - bar.start) * width - 1, 1),
                               height: bar.kind.barHeight * Self.scale)
                        .offset(x: CGFloat(bar.start) * width)
                        .widgetAccentable(bar.kind == .work)
                }
            }
            .frame(width: width, height: geometry.size.height, alignment: .leading)
        }
        .frame(height: HourKind.work.barHeight * Self.scale)
    }

    private func color(_ kind: HourKind) -> Color {
        if renderingMode == .fullColor { return kind.color }
        switch kind {
        case .work: return .textPrimary
        case .stretch: return .textPrimary.opacity(0.45)
        case .sleep: return .textPrimary.opacity(0.3)
        }
    }
}

// MARK: - Jobs (boards JobsWidgetFull, JobsWidgetLarge, decision BW)

/// Small: the next run, large.
struct JobsSmallView: View {
    let jobs: JobsWidgetText

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            WidgetHeader(title: "Next job")
            if let row = jobs.rows.first {
                // Long titles give up lines before the schedule line goes.
                ViewThatFits(in: .vertical) {
                    content(row, titleLines: 3, showsLine: true)
                    content(row, titleLines: 2, showsLine: true)
                    content(row, titleLines: 2, showsLine: false)
                }
            } else {
                WidgetMessage(text: "No upcoming jobs")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeWidgetStyle()
    }

    private func content(_ row: JobWidgetRow, titleLines: Int, showsLine: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
                .meridianFont(.widgetTitle)
                .foregroundStyle(.textPrimary)
                .lineLimit(titleLines)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dayTime(row))
                    .meridianFont(.widgetTime)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .layoutPriority(1)
                Text(jobs.zoneName)
                    .meridianFont(.monoCaption)
                    .foregroundStyle(.textSecondary)
            }
            WidgetCountdown(text: row.countdown, isSoon: row.isSoon)
                .meridianFont(.widgetRowTitle)
            if showsLine {
                Text(row.shortLine)
                    .meridianFont(.widgetDetail)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Medium: up to three runs as rows.
struct JobsMediumView: View {
    let jobs: JobsWidgetText

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Next jobs", trailing: jobs.zoneName)
            if jobs.rows.isEmpty {
                WidgetMessage(text: "No upcoming jobs")
            } else {
                ViewThatFits(in: .vertical) {
                    ForEach((1...min(3, jobs.rows.count)).reversed(), id: \.self) { count in
                        JobRows(rows: Array(jobs.rows.prefix(count)), line: \.shortLine, showsChildren: false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeWidgetStyle()
    }
}

/// Large: the next run large with its full schedule line, then rows with their children.
struct JobsLargeView: View {
    let jobs: JobsWidgetText

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            WidgetHeader(title: "Next jobs", trailing: jobs.zoneName)
            if let first = jobs.rows.first {
                hero(first)
                let rest = Array(jobs.rows.dropFirst())
                if !rest.isEmpty {
                    ViewThatFits(in: .vertical) {
                        ForEach((0...min(4, rest.count)).reversed(), id: \.self) { count in
                            JobRows(rows: Array(rest.prefix(count)), line: \.line, showsChildren: true)
                        }
                    }
                }
            } else {
                WidgetMessage(text: "No upcoming jobs")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeWidgetStyle()
    }

    private func hero(_ row: JobWidgetRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(dayTime(row))
                    .meridianFont(.widgetHero)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .layoutPriority(1)
                Text(jobs.zoneName)
                    .meridianFont(.monoCaption)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: Spacing.xs)
                WidgetCountdown(text: row.countdown, isSoon: row.isSoon)
                    .meridianFont(.widgetTitle)
            }
            Text(row.line)
                .meridianFont(.caption)
                .foregroundStyle(.textSecondary)
            JobChildren(children: row.children)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Rows split by hairlines: time, title and schedule line, countdown.
private struct JobRows: View {
    let rows: [JobWidgetRow]
    let line: KeyPath<JobWidgetRow, String>
    let showsChildren: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                Rectangle().fill(Color.separatorLine).frame(height: 1)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: Spacing.xs) {
                        Text(dayTime(row))
                            .meridianFont(.widgetMono)
                            .foregroundStyle(.textPrimary)
                            .frame(width: 80, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(row.title)
                                .meridianFont(.widgetRowTitle)
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)
                            Text(row[keyPath: line])
                                .meridianFont(.widgetDetail)
                                .foregroundStyle(.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        WidgetCountdown(text: row.countdown, isSoon: row.isSoon)
                            .meridianFont(.widgetRowTitle)
                    }
                    if showsChildren { JobChildren(children: row.children).padding(.leading, 40) }
                }
                .padding(.vertical, 5)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// `07:50 +0:20 Silver transform`: expected after the run (board JobsWidgetLarge).
private struct JobChildren: View {
    let children: [JobWidgetRow.Child]

    var body: some View {
        if !children.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: Spacing.s, verticalSpacing: 4) {
                ForEach(children.indices, id: \.self) { index in
                    let child = children[index]
                    GridRow {
                        Text(child.time).meridianFont(.widgetDetailMono).foregroundStyle(.textSecondary)
                        Text(child.offset).meridianFont(.widgetDetailMono).foregroundStyle(.textTertiary)
                        Text(child.name).meridianFont(.widgetDetail).foregroundStyle(.textSecondary).lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Lock Screen accessories (board JobsLockWidgets, decision BW)

/// Inline: `⏱ Next job 21:30`.
struct NextJobInlineView: View {
    let jobs: JobsWidgetText

    var body: some View {
        Label(WidgetText.nextJobInline(jobs), systemImage: "clock")
            .accessoryTypeSize()
    }
}

/// Circular: a clock over `28m`.
struct NextJobCircularView: View {
    let jobs: JobsWidgetText

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "clock").meridianFont(.widgetHeader)
            Text(jobs.rows.first?.compactCountdown ?? "–")
                .meridianFont(.widgetTitle)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(jobs.rows.first.map { "Next job \($0.countdown)" } ?? "No upcoming jobs")
        .accessoryTypeSize()
    }
}

/// Rectangular: title, `21:30 · ⏱ in 28 min`, the short schedule line.
struct NextJobRectangularView: View {
    let jobs: JobsWidgetText

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let row = jobs.rows.first {
                Text(row.title)
                    .meridianFont(.widgetTitle)
                    .lineLimit(1)
                Text("\(Text(dayTime(row)).monospaced()) · \(Image(systemName: "clock")) \(row.countdown)")
                    .meridianFont(.widgetTitle)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(row.shortLine)
                    .meridianFont(.widgetDetail)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            } else {
                Text("No upcoming jobs").meridianFont(.widgetTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessoryTypeSize()
    }
}

/// Inline: `UTC 15:32`.
struct UTCInlineView: View {
    let now: Date

    var body: some View {
        Text(WidgetText.utcInline(now: now))
            .accessoryTypeSize()
    }
}

/// Circular: `UTC` over `15:32`.
struct UTCCircularView: View {
    let text: ClockWidgetText

    var body: some View {
        VStack(spacing: 0) {
            Text("UTC").meridianFont(.widgetHeader)
            Text(text.utcTime)
                .meridianFont(.widgetMono)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
        .accessoryTypeSize()
    }
}
