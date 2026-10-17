import MeridianCore
import SwiftUI

/// What a card's buttons ask the list to do.
enum TimerAction {
    case pause, resume, addMinute, restart, remove
}

/// One timer (spec §4.4, board TimerUntil). Duration: time left, Ends line, +1 min,
/// pause/resume, cancel and a draining bar. Until: the target and its local
/// equivalent, time left, cancel; no bar, no pause. All wording from `TimerText`.
struct TimerCard: View {
    let timer: CountdownTimer
    let now: Date
    let display: Zone
    let displayIsPhone: Bool
    let perform: (TimerAction) -> Void

    var body: some View {
        let text = TimerText.card(timer, now: now, display: display, displayIsPhone: displayIsPhone)
        let status = timer.status(at: now)

        VStack(alignment: .leading, spacing: Spacing.s) {
            header(text)
            if timer.isDuration {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Spacing.s) {
                        durationInfo(text, status: status)
                        Spacer(minLength: 0)
                        controls(status)
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        durationInfo(text, status: status)
                        controls(status)
                    }
                }
                if let progress = timer.progress(at: now) {
                    ProgressBar(fraction: progress, isActive: status == .running)
                }
            } else {
                untilInfo(text)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.s) {
                        remaining(text)
                        Spacer(minLength: 0)
                        controls(status)
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        remaining(text)
                        controls(status)
                    }
                }
                if let line = text.status {
                    Text(line).meridianFont(.sub).foregroundStyle(.textSecondary)
                }
            }
            ForEach(text.notes, id: \.self) { note in
                NoteLine(systemImage: "clock.arrow.circlepath", text: note)
                    .padding(.horizontal, -Spacing.xs)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: Parts

    private func header(_ text: TimerCardText) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                title(text)
                Spacer(minLength: 0)
                tag(text)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title(text)
                tag(text)
            }
        }
    }

    private func title(_ text: TimerCardText) -> some View {
        Text(text.title)
            .meridianFont(.headline)
            .foregroundStyle(.textPrimary)
    }

    private func tag(_ text: TimerCardText) -> some View {
        Text(text.tag)
            .textCase(.uppercase)
            .tracking(1)
            .meridianFont(.caption)
            .foregroundStyle(.textSecondary)
    }

    private func durationInfo(_ text: TimerCardText, status: CountdownTimer.Status) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            remaining(text)
            if let line = text.status {
                Text(line)
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func remaining(_ text: TimerCardText) -> some View {
        Text(text.remaining)
            .meridianFont(.monoTime)
            .foregroundStyle(.textPrimary)
            .accessibilityLabel(accessibleRemaining)
    }

    /// `Until 02:00 UTC` / `07:30 IST on this phone · Fri`.
    private func untilInfo(_ text: TimerCardText) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let time = text.untilTime {
                Text("Until \(Text(time).font(.system(.body, design: .monospaced, weight: .semibold)))")
                    .meridianFont(.body)
                    .foregroundStyle(.textPrimary)
            }
            if let local = text.localLine {
                Text(local)
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func controls(_ status: CountdownTimer.Status) -> some View {
        HStack(spacing: Spacing.s) {
            if timer.isDuration {
                switch status {
                case .running, .paused:
                    Button { perform(.addMinute) } label: {
                        Text("+1 min")
                            .meridianFont(.headline)
                            .fixedSize()    // natural width, so ViewThatFits stacks instead of squeezing
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: Spacing.minTapTarget)
                            .background(.bgElevated, in: .capsule)
                    }
                    .accessibilityLabel("Add 1 minute")
                    .accessibilityShowsLargeContentViewer()
                    if status == .running {
                        CircleButton(systemImage: "pause.fill", label: "Pause") { perform(.pause) }
                    } else {
                        CircleButton(systemImage: "play.fill", label: "Resume") { perform(.resume) }
                    }
                case .finished:
                    CircleButton(systemImage: "arrow.clockwise", label: "Restart") { perform(.restart) }
                }
            }
            CircleButton(systemImage: "xmark", label: status == .finished ? "Dismiss" : "Cancel") { perform(.remove) }
        }
        .foregroundStyle(.textPrimary)
        .buttonStyle(.plain)
        // Icon controls stop growing at AX1 so the row still fits; long-press shows them large.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// VoiceOver: "6 minutes 42 seconds left".
    private var accessibleRemaining: String {
        let seconds = timer.remainingSeconds(at: now)
        let parts = DateComponentsFormatter.localizedString(from: DateComponents(second: seconds), unitsStyle: .full)
        return seconds == 0 ? "Done" : "\(parts ?? "") left"
    }
}

/// A 44pt round button on `bgElevated` (board TimerUntil).
private struct CircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    /// 48pt at the default size, growing with the glyph.
    @ScaledMetric(relativeTo: .body) private var size = Spacing.minTapTarget + 4

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.body, weight: .semibold))
                .frame(width: size, height: size)
                .background(.bgElevated, in: .circle)
        }
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer {
            Label(label, systemImage: systemImage)
        }
    }
}

/// The draining bar: remaining fraction in accent while running (§3.2 "running
/// progress"), `textTertiary` while paused.
private struct ProgressBar: View {
    let fraction: Double
    let isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bgElevated)
                Capsule()
                    .fill(isActive ? Color.accent : Color.textTertiary)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
