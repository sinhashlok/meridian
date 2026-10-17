import MeridianCore
import SwiftUI

/// BestWindowChip (spec §4.1) as a card: `BEST COMPROMISE`, the range in UTC (decision N),
/// counts, and the weekend-skip note. Outlined with a checkmark while it is the selection.
struct BestWindowCard: View {
    let best: BestWindow
    let viewedDay: CivilDate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(best.window.isAllWork ? "Best time" : "Best compromise")
                        .meridianFont(.caption)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.textSecondary)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                            range
                            Spacer(minLength: 0)
                            counts.multilineTextAlignment(.trailing)
                        }
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            range
                            counts
                        }
                    }
                    if let skip = best.skipNote {
                        Text(skip)
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                    }
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .meridianFont(.headline)
                        .foregroundStyle(.textPrimary)
                        .transition(.symbolEffect)
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight, alignment: .leading)
            .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Color.textPrimary : Color.separatorLine, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(Motion.stateChange, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Moves the scrubber to this time")
    }

    private var range: some View {
        Text(MeetingText.utcRange(start: best.window.interval.start, minutes: minutes, showsDay: best.day != viewedDay))
            .meridianFont(.monoBody).bold()
            .foregroundStyle(.textPrimary)
    }

    private var counts: some View {
        // "3 of 3 awake · Mumbai in stretch" reads as two lines on the board.
        Text(best.countsText.replacingOccurrences(of: " · ", with: "\n"))
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var minutes: Int { Int(best.window.interval.duration / 60) }
}

/// The selected meeting (board Planner): UTC range, date and length, −15/+15, each zone's
/// local time with its tag, and Copy · Share · Now. VoiceOver adjusts by ±30 min.
struct MeetingCard: View {
    @Binding var selection: Date
    @Binding var minutes: Int
    let axis: DateInterval
    let zones: [PlannerZone]
    let now: Date
    let onNow: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let tags = MeetingText.tags(start: selection, minutes: minutes, zones: zones)
        VStack(alignment: .leading, spacing: Spacing.m) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.s) {
                    heading
                    Spacer(minLength: 0)
                    steppers
                }
                VStack(alignment: .leading, spacing: Spacing.s) {
                    heading
                    steppers
                }
            }

            // One zone per row (owner's choice, decision V): name, then times in one aligned
            // column with tags beside them. At accessibility sizes each zone stacks.
            let entries = Array(zip(zones, tags))
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ForEach(entries, id: \.0) { zone, tag in
                        VStack(alignment: .leading, spacing: 2) {
                            zoneName(zone)
                            HStack(spacing: Spacing.xs) { time(in: zone); tagChip(tag) }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: Spacing.xs, verticalSpacing: Spacing.xs) {
                    ForEach(entries, id: \.0) { zone, tag in
                        GridRow {
                            zoneName(zone)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            time(in: zone)
                                .gridColumnAlignment(.trailing)
                            tagChip(tag)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    private func zoneName(_ zone: PlannerZone) -> some View {
        Text(zone.name)
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
    }

    private func time(in zone: PlannerZone) -> some View {
        Text(ZoneClock.wallTime(selection, in: zone.zone))
            .meridianFont(.monoBody).bold()
            .foregroundStyle(.textPrimary)
            .numericTransition()
            .fixedSize()
    }

    @ViewBuilder
    private func tagChip(_ tag: String?) -> some View {
        if let tag {
            Text(tag)
                .meridianFont(.caption)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(.tintStretch, in: .rect(cornerRadius: Radius.chip, style: .continuous))
                .fixedSize()
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MeetingText.utcRange(start: selection, minutes: minutes))
                .meridianFont(.monoBody).bold()
                .foregroundStyle(.textPrimary)
                .numericTransition()
                .accessibilityLabel("Meeting time")
                .accessibilityValue(MeetingText.utcRange(start: selection, minutes: minutes))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: selection = Scrubber.step(selection, byMinutes: 30, in: axis)
                    case .decrement: selection = Scrubber.step(selection, byMinutes: -30, in: axis)
                    @unknown default: break
                    }
                }
            Menu {
                Picker("Length", selection: $minutes) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { Text("\($0) min").tag($0) }
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text(MeetingText.summary(start: selection, minutes: minutes))
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
                .frame(minHeight: Spacing.minTapTarget)
                .contentShape(.rect)
            }
            .accessibilityLabel("Meeting length, \(minutes) minutes")
        }
    }

    private var steppers: some View {
        HStack(spacing: Spacing.xs) {
            Button("−15") { selection = Scrubber.step(selection, byMinutes: -15, in: axis) }
                .accessibilityLabel("15 minutes earlier")
            Button("+15") { selection = Scrubber.step(selection, byMinutes: 15, in: axis) }
                .accessibilityLabel("15 minutes later")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.textPrimary)          // secondary controls stay neutral (§3.2)
    }

    private var actions: some View {
        let text = MeetingText.make(start: selection, minutes: minutes, zones: zones, now: now)
        // Side by side normally; stacked full-width at accessibility sizes so labels stay.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.xs))
        return layout {
            CopyButton(text: text)
                .buttonStyle(.bordered)
            ShareLink(item: text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Button("Now") { onNow?() }
                .disabled(onNow == nil)
                .frame(minHeight: Spacing.minTapTarget)
                .accessibilityHint("Moves the scrubber back to the current time")
        }
        .controlSize(.large)
        .tint(.textPrimary)          // secondary controls stay neutral (§3.2)
    }
}

/// Full-width outlined `+ Add zone` (boards Planner and ClocksBanner).
struct AddZoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add zone", systemImage: "plus")
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget + Spacing.xxs)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.fillControl, lineWidth: 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
