import MeridianCore
import SwiftUI

/// The Planner rows on one axis (spec §4.1): bars placed by real UTC instants on the
/// reference zone's day, encoded by height first (work 26pt, stretch 16pt, sleep 4pt).
/// Overlays: best-window bracket (text.primary), now-line (accent), selection line.
/// A horizontal drag that starts on a track scrubs; dragging away vertically fine-scrubs.
struct PlannerGrid: View {
    let day: PlannerDay
    let reference: Zone
    let now: Date
    @Binding var selection: Date
    let bracket: DateInterval?
    let timeSuffix: String

    @ScaledMetric(relativeTo: .headline) private var labelWidth: CGFloat = 96
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0
    @State private var bubbleWidth: CGFloat = 60
    @State private var dragAxis: Axis?
    @State private var lastX: CGFloat = 0
    @State private var scrubFraction: Double = 0

    static let trackHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .footnote) private var bubbleHeight: CGFloat = 28

    private var isStacked: Bool { typeSize.isAccessibilitySize }
    private var trackX: CGFloat { isStacked ? 0 : labelWidth + Spacing.s }
    private var trackWidth: CGFloat { max(width - trackX, 1) }

    private func x(_ instant: Date) -> CGFloat {
        trackX + CGFloat(Scrubber.fraction(of: instant, in: day.axis)) * trackWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            bubble
            rows
            ticks
        }
        .sensoryFeedback(Haptic.selection, trigger: Scrubber.wallTime(of: selection, in: reference).hour)
    }

    // MARK: Parts

    private var bubble: some View {
        Text(ZoneClock.wallTime(selection, in: reference) + timeSuffix)
            .meridianFont(.monoCaption)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(.bgElevated, in: .capsule)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { bubbleWidth = $0 }
            // Centre on the selection, but keep the whole bubble on screen at any text size.
            .position(x: min(max(x(selection), bubbleWidth / 2), max(width - bubbleWidth / 2, bubbleWidth / 2)),
                      y: bubbleHeight / 2)
            .frame(height: bubbleHeight)
            .accessibilityHidden(true)               // the scrub controls speak the time
    }

    private var rows: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(day.rows, id: \.zone) { row in
                PlannerRowView(row: row, axis: day.axis, selection: selection,
                               markers: day.transitions.filter { $0.zoneName == row.zone.name }.map(\.transition),
                               isStacked: isStacked, labelWidth: labelWidth, trackWidth: trackWidth)
            }
        }
        // Take the whole column first: the tracks size from this width, so measuring an
        // unconstrained VStack would feed their own size back in.
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .overlay(alignment: .topLeading) { lines }
        .contentShape(.rect)
        .simultaneousGesture(scrub)
    }

    private var lines: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                if let bracket, bracket.intersects(day.axis) {
                    let start = x(max(bracket.start, day.axis.start)), end = x(min(bracket.end, day.axis.end))
                    RoundedRectangle(cornerRadius: Radius.bar, style: .continuous)
                        .strokeBorder(Color.textPrimary, lineWidth: 1.5)
                        .frame(width: max(end - start, 2), height: height)
                        .offset(x: start)
                }
                Rectangle().fill(Color.textPrimary).frame(width: 2, height: height).offset(x: x(selection) - 1)
                // Drawn last so "now" stays visible when the selection sits on it.
                if day.axis.contains(now) {
                    Rectangle().fill(Color.accent).frame(width: 2, height: height).offset(x: x(now) - 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Hour ticks at 00, 06, 12, 18 on the reference zone's wall clock, so a 25-hour
    /// day shows its extra hour between ticks.
    private var ticks: some View {
        ZStack(alignment: .topLeading) {
            ForEach([0, 6, 12, 18], id: \.self) { hour in
                let instant = Scrubber.instant(keeping: ClockTime(hour, 0), on: day.date, in: reference)
                Text(hour < 10 ? "0\(hour)" : "\(hour)")
                    .meridianFont(.tick)
                    .foregroundStyle(.textTertiary)
                    .fixedSize()
                    .position(x: x(instant) + 8, y: 8)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    // MARK: Scrubbing

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragAxis == nil {
                    // Engage only on horizontal drags that start on a track.
                    let startsOnTrack = value.startLocation.x >= trackX
                    let isHorizontal = abs(value.translation.width) >= abs(value.translation.height)
                    dragAxis = startsOnTrack && isHorizontal ? .horizontal : .vertical
                    guard dragAxis == .horizontal else { return }
                    lastX = value.startLocation.x
                    scrubFraction = Double((value.startLocation.x - trackX) / trackWidth)
                }
                guard dragAxis == .horizontal else { return }
                // Fine-scrub: more than 60pt above or below the start moves at quarter speed.
                let speed: CGFloat = abs(value.translation.height) > 60 ? 0.25 : 1
                scrubFraction += Double((value.location.x - lastX) * speed / trackWidth)
                scrubFraction = min(max(scrubFraction, 0), 1)
                lastX = value.location.x
                selection = Scrubber.instant(atFraction: scrubFraction, in: day.axis)
            }
            .onEnded { _ in dragAxis = nil }
    }
}

/// One zone: name and its time at the selection, then the track.
private struct PlannerRowView: View {
    let row: PlannerRow
    let axis: DateInterval
    let selection: Date
    let markers: [MeridianCore.Transition]   // SwiftUI also has a `Transition`
    let isStacked: Bool
    let labelWidth: CGFloat
    let trackWidth: CGFloat

    var body: some View {
        let kind = OverlapEngine.window(starting: selection, minutes: OverlapEngine.slotMinutes, zones: [row.zone]).kinds[0]
        let time = ZoneClock.wallTime(selection, in: row.zone.zone)
        Group {
            if isStacked {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    label(time: time)
                    track
                }
            } else {
                HStack(spacing: Spacing.s) {
                    label(time: time).frame(width: labelWidth, alignment: .leading)
                    track
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.zone.name), \(time), \(kind.spokenName)")
    }

    private func label(time: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(row.zone.name)
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
            Text(time)
                .meridianFont(.sub)
                .monospacedDigit()
                .foregroundStyle(.textSecondary)
        }
    }

    private var track: some View {
        ZStack(alignment: .leading) {
            ForEach(row.segments, id: \.interval) { segment in
                let start = CGFloat(Scrubber.fraction(of: segment.interval.start, in: axis)) * trackWidth
                let end = CGFloat(Scrubber.fraction(of: segment.interval.end, in: axis)) * trackWidth
                RoundedRectangle(cornerRadius: Radius.bar, style: .continuous)
                    .fill(segment.kind.color)
                    .frame(width: max(end - start - 1, 1), height: segment.kind.barHeight)
                    .offset(x: start)
            }
            // Skipped/repeated-hour marker where this zone's clocks change.
            ForEach(markers, id: \.instant) { marker in
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 0, y: PlannerGrid.trackHeight))
                }
                .stroke(Color.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: 1, height: PlannerGrid.trackHeight)
                .offset(x: CGFloat(Scrubber.fraction(of: marker.instant, in: axis)) * trackWidth)
            }
        }
        .frame(width: trackWidth, height: PlannerGrid.trackHeight, alignment: .leading)
    }
}

extension HourKind {
    /// Height first, colour second (CLAUDE.md UI rules).
    var barHeight: CGFloat {
        switch self {
        case .work: 26
        case .stretch: 16
        case .sleep: 4
        }
    }

    var color: Color {
        switch self {
        case .work: .accent
        case .stretch: .tintStretch
        case .sleep: .tintSleep
        }
    }

    var spokenName: String {
        switch self {
        case .work: "work hours"
        case .stretch: "stretch hours"
        case .sleep: "asleep"
        }
    }
}
