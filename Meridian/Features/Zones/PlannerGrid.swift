import MeridianCore
import SwiftUI

/// The Planner rows on one axis (spec §4.1): bars placed by real UTC instants on the
/// reference zone's day, encoded by height first (work 26pt, stretch 16pt, sleep 4pt).
/// Above the card, a bubble names the selected time. Inside: header with ticks, rows,
/// and overlays (repeated-hour shading, fault lines, best-window bracket, the selected
/// meeting as a band with a handle, the accent now-line).
/// A horizontal drag that starts on a track scrubs; dragging away vertically fine-scrubs.
///
/// While dragging, the time lives in `dragged` here, so only this grid redraws per frame;
/// `selection` (the Planner's) changes once, on release. The bars are an equatable view,
/// so SwiftUI skips them while scrubbing.
struct PlannerGrid: View {
    let day: PlannerDay
    let reference: Zone
    let referenceName: String
    let home: PlannerZone?
    let zones: [PlannerZone]
    let now: Date
    @Binding var selection: Date
    let minutes: Int
    let bracket: DateInterval?
    @Binding var isScrubbing: Bool

    @ScaledMetric(relativeTo: .headline) private var labelWidth: CGFloat = 116
    @ScaledMetric(relativeTo: .headline) private var knobSize: CGFloat = 26
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0
    @State private var dragAxis: Axis?
    @State private var lastX: CGFloat = 0
    @State private var scrubFraction: Double = 0
    /// The scrubbed time while a drag is in progress.
    @State private var dragged: Date?

    /// What the grid shows: the drag in progress, else the Planner's selection.
    private var shown: Date { dragged ?? selection }

    static let trackHeight: CGFloat = 32
    private static let cardPadding = Spacing.s

    private var isStacked: Bool { typeSize.isAccessibilitySize }
    private var trackX: CGFloat { isStacked ? 0 : labelWidth + Spacing.s }
    private var trackWidth: CGFloat { max(width - trackX, 1) }

    private func x(_ instant: Date) -> CGFloat {
        trackX + CGFloat(Scrubber.fraction(of: instant, in: day.axis)) * trackWidth
    }

    var body: some View {
        let faults = day.faultLines(reference: reference)
        let change = day.referenceChange(reference: reference, referenceName: referenceName)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            bubble
            VStack(alignment: .leading, spacing: Spacing.s) {
                header(change: change)
                rows(faults: faults, change: change)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .padding(Self.cardPadding)
            .padding(.bottom, knobSize / 2)
            .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
        }
        .sensoryFeedback(Haptic.selection, trigger: Scrubber.wallTime(of: shown, in: reference).hour)
    }

    // MARK: Bubble

    /// `21:30 IST` over `3 of 3 awake · Mumbai in stretch`; while scrubbing the first line
    /// adds UTC. Always the grid card's full width so it never jumps as the text changes
    /// (decision V); only its pointer follows the selection line.
    private var bubble: some View {
        let full = width + 2 * Self.cardPadding
        // The pointer stays under the selection line, inside the bubble's rounded corners.
        let pointerX = min(max(Self.cardPadding + x(shown), Radius.chip + 6), full - Radius.chip - 6)
        let counts = OverlapEngine.window(starting: shown, minutes: minutes, zones: zones).countsText
        return VStack(alignment: .leading, spacing: 2) {
            Text(Scrubber.bubbleText(shown, reference: reference, withUTC: isScrubbing))
                .meridianFont(.monoCaption).bold()
                .foregroundStyle(.textPrimary)
            // At least two lines tall, so the grid below doesn't jump while scrubbing;
            // more zones can still grow it.
            ZStack(alignment: .topLeading) {
                Text("\n").hidden()
                Text(counts)
                    .foregroundStyle(.textSecondary)
            }
            .meridianFont(.caption)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bgElevated, in: .rect(cornerRadius: Radius.chip, style: .continuous))
        .background(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.bgElevated)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .offset(x: pointerX - 5, y: 5)
        }
        .accessibilityHidden(true)               // the meeting card speaks the time
    }

    // MARK: Header

    /// `IST · Thu 15` (+ `25-hour day`) beside hour ticks at 00, 06, 12, 18 on the reference
    /// zone's wall clock, so a 25-hour day shows its extra hour between ticks. A reference
    /// clock change adds its label (`01 BST · 01 GMT`) above the ticks.
    @ViewBuilder
    private func header(change: ReferenceChange?) -> some View {
        let title = VStack(alignment: .leading, spacing: 0) {
            Text(day.headerTitle(reference: reference, referenceName: referenceName))
                .meridianFont(.caption)
                .foregroundStyle(.textSecondary)
            if let length = day.lengthNote {
                Text(length)
                    .meridianFont(.caption).bold()
                    .foregroundStyle(.textPrimary)
            }
        }
        let ticks = VStack(alignment: .leading, spacing: 2) {
            if let change { changeLabel(change) }
            ZStack(alignment: .topLeading) {
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    let instant = Scrubber.instant(keeping: ClockTime(hour, 0), on: day.date, in: reference)
                    Text(hour < 10 ? "0\(hour)" : "\(hour)")
                        .meridianFont(.tick)
                        .monospaced()
                        .foregroundStyle(.textTertiary)
                        .fixedSize()
                        .offset(x: x(instant) - trackX)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHidden(true)

        if isStacked {
            VStack(alignment: .leading, spacing: Spacing.xs) { title; ticks }
        } else {
            HStack(alignment: .bottom, spacing: Spacing.s) {
                title.frame(width: labelWidth, alignment: .leading)
                ticks
            }
        }
    }

    private func changeLabel(_ change: ReferenceChange) -> some View {
        let start = change.repeated.map { x($0.start) } ?? x(change.instant)
        let bracketWidth = change.repeated.map { x($0.end) - x($0.start) } ?? 0
        return HStack(spacing: Spacing.xxs) {
            if bracketWidth > 0 {
                // ⌐¬ over both occurrences of the repeated hour.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 8))
                    path.addLine(to: CGPoint(x: 0, y: 2))
                    path.addLine(to: CGPoint(x: bracketWidth, y: 2))
                    path.addLine(to: CGPoint(x: bracketWidth, y: 8))
                }
                .stroke(Color.textSecondary, lineWidth: 1)
                .frame(width: bracketWidth, height: 8)
            }
            Text(change.label)
                .meridianFont(.monoCaption)
                .foregroundStyle(.textPrimary)
                .fixedSize()
        }
        .offset(x: max(start - trackX, 0))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Rows and overlays

    private func rows(faults: [FaultLine], change: ReferenceChange?) -> some View {
        VStack(spacing: Spacing.s) {
            ForEach(day.rows, id: \.zone) { row in
                PlannerRowView(row: row, axis: day.axis, caption: day.caption(for: row.zone, now: now),
                               selection: shown, isScrubbing: isScrubbing, isHome: row.zone == home,
                               markers: day.transitions.filter { $0.zoneName == row.zone.name }.map(\.transition),
                               fault: faults.first { $0.zoneName == row.zone.name },
                               isStacked: isStacked, labelWidth: labelWidth, trackX: trackX, trackWidth: trackWidth)
            }
        }
        .overlay(alignment: .topLeading) { lines(faults: faults, change: change) }
        .contentShape(.rect)
        .simultaneousGesture(scrub)
    }

    private func lines(faults: [FaultLine], change: ReferenceChange?) -> some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                if let repeated = change?.repeated {
                    Rectangle()
                        .fill(Color.textPrimary.opacity(0.07))
                        .frame(width: x(repeated.end) - x(repeated.start), height: height)
                        .offset(x: x(repeated.start))
                }
                ForEach(faults, id: \.instant) { fault in
                    dashedLine(height: height, color: .textTertiary, width: 1).offset(x: x(fault.instant))
                }
                if let bracket, bracket.intersects(day.axis), bracket != meeting {
                    // Corner caps, not a full outline: an outline next to the selection band
                    // read as a second selection line.
                    let start = x(max(bracket.start, day.axis.start)), end = x(min(bracket.end, day.axis.end))
                    let width = max(end - start, 2), cap: CGFloat = 6
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: cap))
                        path.addLine(to: .zero)
                        path.addLine(to: CGPoint(x: width, y: 0))
                        path.addLine(to: CGPoint(x: width, y: cap))
                        path.move(to: CGPoint(x: 0, y: height - cap))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: width, y: height - cap))
                    }
                    .stroke(Color.textPrimary, lineWidth: 1.5)
                    .frame(width: width, height: height)
                    .offset(x: start)
                }
                // The selected meeting: a band as long as the meeting, a leading line, a handle.
                let start = x(shown), end = x(min(meeting.end, day.axis.end))
                Rectangle()
                    .fill(Color.textPrimary.opacity(0.14))
                    .frame(width: max(end - start, 2), height: height)
                    .offset(x: start)
                Rectangle().fill(Color.textPrimary).frame(width: 2, height: height).offset(x: start - 1)
                Circle()
                    .fill(Color.textPrimary)
                    .frame(width: knobSize, height: knobSize)
                    .scaleEffect(isScrubbing ? 1.25 : 1)
                    .dragShadow()
                    .offset(x: start - knobSize / 2, y: height - knobSize / 2 + Self.cardPadding / 2)
                    .animation(Motion.press, value: isScrubbing)
                // Drawn last so "now" stays visible when the selection sits on it.
                if day.axis.contains(now) {
                    Rectangle().fill(Color.accent).frame(width: 2, height: height).offset(x: x(now) - 1)
                    Circle().fill(Color.accent).frame(width: 8, height: 8).offset(x: x(now) - 4, y: -4)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var meeting: DateInterval { DateInterval(start: shown, duration: TimeInterval(minutes * 60)) }

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
                    isScrubbing = true
                    lastX = value.startLocation.x
                    scrubFraction = Double((value.startLocation.x - trackX) / trackWidth)
                }
                guard dragAxis == .horizontal else { return }
                // Fine-scrub: more than 60pt above or below the start moves at quarter speed.
                let speed: CGFloat = abs(value.translation.height) > 60 ? 0.25 : 1
                scrubFraction += Double((value.location.x - lastX) * speed / trackWidth)
                scrubFraction = min(max(scrubFraction, 0), 1)
                lastX = value.location.x
                dragged = Scrubber.instant(atFraction: scrubFraction, in: day.axis)
            }
            .onEnded { _ in
                if let dragged { selection = dragged }
                dragged = nil
                dragAxis = nil
                isScrubbing = false
            }
    }
}

/// A vertical dashed line, `height` tall.
private func dashedLine(height: CGFloat, color: Color, width: CGFloat) -> some View {
    Path { path in
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: height))
    }
    .stroke(color, style: StrokeStyle(lineWidth: width, dash: [4, 3]))
    .frame(width: width, height: height)
}

/// One zone: name (house for home) and a caption, then the track. The caption is the
/// zone's time now or its offsets; while scrubbing, the selected time and hour kind.
private struct PlannerRowView: View {
    let row: PlannerRow
    let axis: DateInterval
    let caption: String
    let selection: Date
    let isScrubbing: Bool
    let isHome: Bool
    let markers: [MeridianCore.Transition]   // SwiftUI also has a `Transition`
    let fault: FaultLine?
    let isStacked: Bool
    let labelWidth: CGFloat
    let trackX: CGFloat
    let trackWidth: CGFloat

    @State private var chipWidth: CGFloat = 0

    var body: some View {
        let kind = OverlapEngine.window(starting: selection, minutes: OverlapEngine.slotMinutes, zones: [row.zone]).kinds[0]
        let time = ZoneClock.wallTime(selection, in: row.zone.zone)
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let fault { chip(fault) }
            if isStacked {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    label(time: time, kind: kind)
                    track
                }
            } else {
                HStack(spacing: Spacing.s) {
                    label(time: time, kind: kind).frame(width: labelWidth, alignment: .leading)
                    track
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.zone.name), \(time), \(kind.spokenName)")
    }

    private func label(time: String, kind: HourKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xxs) {
                if isHome {
                    Image(systemName: "house.fill")
                        .meridianFont(.caption)
                        .foregroundStyle(.textSecondary)
                }
                Text(row.zone.name)
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
            }
            if isScrubbing {
                Text("\(Text(time).bold().foregroundStyle(.textPrimary)) \(kind.shortName)")
                    .meridianFont(.monoCaption)
                    .foregroundStyle(.textSecondary)
            } else {
                Text(caption)
                    .meridianFont(.monoCaption)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    /// `↺ London −1h, Sun 25 Oct` starting at the fault line, kept inside the row.
    private func chip(_ fault: FaultLine) -> some View {
        let x = trackX + CGFloat(Scrubber.fraction(of: fault.instant, in: axis)) * trackWidth
        return Label(fault.chip, systemImage: "clock.arrow.circlepath")
            .meridianFont(.caption).bold()
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(Color.textSecondary, lineWidth: 1)
            }
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chipWidth = $0 }
            .offset(x: max(0, min(x, trackX + trackWidth - chipWidth)))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var track: some View {
        PlannerTrack(segments: row.segments, markers: markers, axis: axis, width: trackWidth)
            .equatable()
    }
}

/// One row's bars (height first: work 26, stretch 16, sleep 4) and its clock-change
/// markers. Equatable: its inputs don't change while scrubbing, so SwiftUI skips it.
private struct PlannerTrack: View, Equatable {
    let segments: [Segment]
    let markers: [MeridianCore.Transition]
    let axis: DateInterval
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(segments, id: \.interval) { segment in
                let start = CGFloat(Scrubber.fraction(of: segment.interval.start, in: axis)) * width
                let end = CGFloat(Scrubber.fraction(of: segment.interval.end, in: axis)) * width
                RoundedRectangle(cornerRadius: Radius.bar, style: .continuous)
                    .fill(segment.kind.color)
                    .frame(width: max(end - start - 1, 1), height: segment.kind.barHeight)
                    .offset(x: start)
            }
            // Skipped/repeated-hour marker where this zone's clocks change.
            ForEach(markers, id: \.instant) { marker in
                dashedLine(height: PlannerGrid.trackHeight, color: .textPrimary, width: 2)
                    .offset(x: CGFloat(Scrubber.fraction(of: marker.instant, in: axis)) * width - 1)
            }
        }
        .frame(width: width, height: PlannerGrid.trackHeight, alignment: .leading)
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

    /// Row caption while scrubbing (board PlannerScrub).
    var shortName: String {
        switch self {
        case .work: "work"
        case .stretch: "stretch"
        case .sleep: "asleep"
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
