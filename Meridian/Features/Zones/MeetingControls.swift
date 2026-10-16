import MeridianCore
import SwiftUI
import UIKit  // UIPasteboard

/// −15 · selected time · +15 (spec §4.1 scrubber buttons). VoiceOver adjusts by ±30 min.
struct ScrubControls: View {
    @Binding var selection: Date
    let axis: DateInterval
    let reference: Zone
    let timeSuffix: String
    let onNow: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button("−15") { selection = Scrubber.step(selection, byMinutes: -15, in: axis) }
                .accessibilityLabel("15 minutes earlier")
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text(ZoneClock.wallTime(selection, in: reference) + timeSuffix)
                    .meridianFont(.monoTime)
                    .foregroundStyle(.textPrimary)
                    .contentTransition(.numericText())
                if let onNow {
                    Button("Back to now", action: onNow)
                        .meridianFont(.caption)
                        .frame(minHeight: Spacing.minTapTarget)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Meeting time")
            .accessibilityValue(ZoneClock.wallTime(selection, in: reference) + timeSuffix)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: selection = Scrubber.step(selection, byMinutes: 30, in: axis)
                case .decrement: selection = Scrubber.step(selection, byMinutes: -30, in: axis)
                @unknown default: break
                }
            }
            Spacer(minLength: 0)
            Button("+15") { selection = Scrubber.step(selection, byMinutes: 15, in: axis) }
                .accessibilityLabel("15 minutes later")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.textPrimary)          // secondary controls stay neutral (§3.2)
    }
}

/// BestWindowChip (spec §4.1) with the no-overlap banner and the weekend-skip note.
struct BestWindowSection: View {
    let best: BestWindow
    let reference: Zone
    let referenceName: String
    let viewedDay: CivilDate
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let banner = best.noOverlapBanner { InlineBanner(text: banner) }
            if let skip = best.skipNote {
                Text(skip)
                    .meridianFont(.caption)
                    .foregroundStyle(.textSecondary)
            }
            Button(action: onSelect) {
                HStack(spacing: Spacing.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(best.window.isAllWork ? "Best time" : "Best compromise")
                            .meridianFont(.caption)
                            .foregroundStyle(.textSecondary)
                        Text(rangeText)
                            .meridianFont(.headline)
                            .foregroundStyle(.textPrimary)
                        Text(best.countsText)
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer(minLength: Spacing.s)
                    Image(systemName: "arrow.forward.to.line")
                        .foregroundStyle(.textSecondary)
                }
                .padding(Spacing.s)
                .frame(minHeight: Spacing.minRowHeight)
                .background(.bgSurface, in: .rect(cornerRadius: Radius.row, style: .continuous))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Moves the scrubber to this time")
        }
    }

    private var rangeText: String {
        let start = ZoneClock.wallTime(best.window.interval.start, in: reference)
        let end = ZoneClock.wallTime(best.window.interval.end, in: reference)
        let day = best.day == viewedDay ? "" : "\(best.day.shortText) · "
        return "\(day)\(start)–\(end) \(referenceName)"
    }
}

/// Meeting length, Copy and Share (spec §4.1 Copy/Share text).
struct MeetingActions: View {
    @Binding var minutes: Int
    let text: String

    @State private var copies = 0
    @State private var showsCopied = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            Menu {
                Picker("Length", selection: $minutes) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { Text("\($0) min").tag($0) }
                }
            } label: {
                Label("\(minutes) min", systemImage: "timer")
                    .frame(minHeight: Spacing.minTapTarget)
            }
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = text
                copies += 1
                showsCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showsCopied = false
                }
            } label: {
                // Success = checkmark glyph swap (spec §3.1).
                Label(showsCopied ? "Copied" : "Copy", systemImage: showsCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.bordered)
            ShareLink(item: text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .tint(.textPrimary)          // secondary controls stay neutral (§3.2)
        .sensoryFeedback(Haptic.success, trigger: copies)
    }
}
