import AppIntents
import SwiftUI

// The Live Activity content views (boards LiveActivity and Island). They live in Shared/
// so the widget draws them and the app's debug preview (`-MeridianScreen liveActivity`)
// can show them at real sizes; Simulator screenshots don't capture Live Activities.
//
// Height budget: iOS gives a Lock Screen activity about 160pt. Header, countdown row,
// bar and two meeting lines with 8pt gaps and 12pt vertical padding come to ~158pt
// (measured in the debug preview).
// Running countdowns use the system's self-updating `Text(timerInterval:)` and
// `ProgressView(timerInterval:)` (decision AK: they print `6:42`, not `06:42`).

enum LiveLayout {
    static let padding = EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
    static let gap: CGFloat = 8
    static let countdownSize: CGFloat = 42
    static let button: CGFloat = 44
}

// MARK: - Parts

/// Time left: ticking to `end` while running, `paused` text otherwise.
struct LiveCountdown: View {
    let end: Date?
    let paused: String?

    var body: some View {
        if let end {
            // `max` keeps the range valid once the end has passed (shows 0:00).
            Text(timerInterval: Date.now...max(end, .now), countsDown: true)
        } else {
            Text(paused ?? "")
        }
    }
}

/// A draining bar or ring: live from `start` to `end`, else the paused fraction, else
/// nothing (Until timers have no progress).
struct LiveProgress: View {
    enum Shape { case bar, ring }

    let shape: Shape
    let start: Date?
    let end: Date?
    let pausedFraction: Double?
    let tint: Color

    var body: some View {
        if let start, let end, start < end {
            styled(ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() }
                currentValueLabel: { EmptyView() })
        } else if let pausedFraction {
            styled(ProgressView(value: pausedFraction))
        }
    }

    @ViewBuilder
    private func styled(_ view: some View) -> some View {
        switch shape {
        case .bar:
            // The system bar is 4pt with a faint track; board LiveActivity's is thicker.
            view.tint(tint).scaleEffect(x: 1, y: 1.6, anchor: .center)
        case .ring:
            view.progressViewStyle(.circular).tint(tint)
        }
    }
}

/// A Live Activity button that runs an intent in the app (decision BA): a 44pt circle
/// with a symbol, or a capsule with a label. Neutral `bgElevated`, like the app's pills.
struct LiveButton<Intent: AppIntent>: View {
    let title: String
    let systemImage: String
    let intent: Intent
    var iconOnly = false

    var body: some View {
        Button(intent: intent) {
            if iconOnly {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: LiveLayout.button, height: LiveLayout.button)
                    .background(.bgElevated, in: .circle)
            } else {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(.bgElevated, in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.textPrimary)
        .accessibilityLabel(title)
    }
}

/// Symbol and one line of context: `◎ Focus · 1 of 4 · Ends 21:28 IST`.
struct LiveHeader: View {
    let systemImage: String
    let text: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing).foregroundStyle(.textSecondary)
            }
        }
        .font(.system(size: 15))
    }
}

// MARK: - Session

extension SessionActivityAttributes.ContentState {
    var isPaused: Bool { endDate == nil }
    /// Focus accent, break `textSecondary`, paused `textTertiary` (as in the app).
    var tint: Color { isPaused ? .textTertiary : isFocus ? .accent : .textSecondary }
}

/// Board LiveActivity: header, countdown with Pause and Skip, bar, the meeting line.
struct SessionLockScreenView: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: LiveLayout.gap) {
            LiveHeader(systemImage: "scope", text: "\(state.phase) · \(state.ends)")
            HStack(alignment: .center, spacing: 12) {
                LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                    .font(.system(size: LiveLayout.countdownSize, weight: .light).monospacedDigit())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                SessionPauseButton(state: state, iconOnly: true)
                LiveButton(title: "Skip to next phase", systemImage: "forward.end.fill",
                           intent: SessionActionIntent(.skip), iconOnly: true)
            }
            LiveProgress(shape: .bar, start: state.phaseStart, end: state.endDate, pausedFraction: state.pausedFraction,
                         tint: state.tint)
            SessionMeetingLines(state: state)
        }
        .padding(LiveLayout.padding)
    }
}

/// Board Island, expanded: ring, phase and end, countdown on top; meeting line and
/// Pause / +5 min / Stop below.
struct SessionExpandedTop: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SessionRing(state: state).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.phase)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(state.ends)
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                .font(.system(size: 40, weight: .light).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }
}

struct SessionExpandedBottom: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SessionMeetingLines(state: state)
            HStack(spacing: 8) {
                SessionPauseButton(state: state)
                LiveButton(title: "+5 min", systemImage: "plus", intent: SessionActionIntent(.addFive))
                LiveButton(title: "Stop", systemImage: "stop.fill", intent: SessionActionIntent(.stop))
            }
        }
    }
}

struct SessionRing: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        LiveProgress(shape: .ring, start: state.phaseStart, end: state.endDate, pausedFraction: state.pausedFraction,
                     tint: state.tint)
    }
}

/// `Best compromise in 21 min · 16:00 UTC` over `3 of 3 awake · Mumbai in stretch`.
struct SessionMeetingLines: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        if let title = state.meetingTitle {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                if let detail = state.meetingDetail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }
}

/// Pause while running, Resume while paused.
struct SessionPauseButton: View {
    let state: SessionActivityAttributes.ContentState
    var iconOnly = false

    var body: some View {
        LiveButton(title: state.isPaused ? "Resume" : "Pause", systemImage: state.isPaused ? "play.fill" : "pause.fill",
                   intent: SessionActionIntent(state.isPaused ? .resume : .pause), iconOnly: iconOnly)
    }
}

// MARK: - Timer

extension TimerActivityAttributes.ContentState {
    /// Duration timers have a bar (running) or a paused fraction; Until timers neither.
    var isDuration: Bool { progressStart != nil || pausedFraction != nil }
    var isPaused: Bool { endDate == nil }
    var tint: Color { isPaused ? .textTertiary : .accent }
}

/// Header with "+N more", countdown with Pause and +1 min (duration timers), bar.
struct TimerLockScreenView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: LiveLayout.gap) {
            LiveHeader(systemImage: "timer", text: "\(state.title) · \(state.caption)", trailing: state.more)
            HStack(alignment: .center, spacing: 12) {
                LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                    .font(.system(size: LiveLayout.countdownSize, weight: .light).monospacedDigit())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if state.isDuration {
                    TimerPauseButton(state: state, iconOnly: true)
                    LiveButton(title: "Add 1 minute", systemImage: "goforward.plus",
                               intent: TimerActionIntent(.addMinute, timerID: state.timerID), iconOnly: true)
                } else {
                    LiveButton(title: "Cancel timer", systemImage: "xmark",
                               intent: TimerActionIntent(.cancel, timerID: state.timerID), iconOnly: true)
                }
            }
            LiveProgress(shape: .bar, start: state.progressStart, end: state.endDate,
                         pausedFraction: state.pausedFraction, tint: state.tint)
        }
        .padding(LiveLayout.padding)
    }
}

struct TimerExpandedTop: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TimerRing(state: state).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text([state.caption, state.more].compactMap(\.self).joined(separator: " · "))
                    .font(.system(size: 14))
                    .foregroundStyle(.textSecondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            LiveCountdown(end: state.endDate, paused: state.pausedRemaining)
                .font(.system(size: 40, weight: .light).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }
}

/// Pause / +1 min / Cancel (Until timers: Cancel only).
struct TimerExpandedBottom: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            if state.isDuration {
                TimerPauseButton(state: state)
                LiveButton(title: "+1 min", systemImage: "plus", intent: TimerActionIntent(.addMinute, timerID: state.timerID))
            }
            LiveButton(title: "Cancel", systemImage: "xmark", intent: TimerActionIntent(.cancel, timerID: state.timerID))
        }
    }
}

/// Drains with a duration timer; a timer glyph for Until timers.
struct TimerRing: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        if state.isDuration {
            LiveProgress(shape: .ring, start: state.progressStart, end: state.endDate,
                         pausedFraction: state.pausedFraction, tint: state.tint)
        } else {
            Image(systemName: "timer")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.accent)
        }
    }
}

struct TimerPauseButton: View {
    let state: TimerActivityAttributes.ContentState
    var iconOnly = false

    var body: some View {
        LiveButton(title: state.isPaused ? "Resume" : "Pause", systemImage: state.isPaused ? "play.fill" : "pause.fill",
                   intent: TimerActionIntent(state.isPaused ? .resume : .pause, timerID: state.timerID),
                   iconOnly: iconOnly)
    }
}

// MARK: - Sample states (widget previews and the app's debug preview)

extension SessionActivityAttributes.ContentState {
    /// Board LiveActivity: Focus 1 of 4 with 18:42 left.
    static var sample: Self {
        Self(phase: "Focus · 1 of 4", ends: "Ends 21:28 IST", isFocus: true, endDate: .now.addingTimeInterval(1122),
             phaseStart: .now.addingTimeInterval(-378), pausedRemaining: nil, pausedFraction: nil,
             meetingTitle: "Best compromise in 21 min · 16:00 UTC", meetingDetail: "3 of 3 awake · Mumbai in stretch")
    }

    /// The phone screenshot's case: no window today, so the next day's.
    static var sampleNoWindow: Self {
        Self(phase: "Focus · 1 of 4", ends: "Ends 12:44 IST", isFocus: true, endDate: .now.addingTimeInterval(1487),
             phaseStart: .now.addingTimeInterval(-13), pausedRemaining: nil, pausedFraction: nil,
             meetingTitle: "No shared window today · next Mon 16:00 UTC", meetingDetail: "3 of 3 awake · Mumbai in stretch")
    }

    static var samplePaused: Self {
        Self(phase: "Focus · 1 of 4", ends: "Paused", isFocus: true, endDate: nil, phaseStart: nil,
             pausedRemaining: "18:42", pausedFraction: 0.748, meetingTitle: nil, meetingDetail: nil)
    }
}

extension TimerActivityAttributes.ContentState {
    /// Board TimerUntil's Standup prep, 06:42 left, with the Until timer behind it.
    static var sample: Self {
        Self(timerID: UUID(), title: "Standup prep", caption: "Ends 21:16 IST", endDate: .now.addingTimeInterval(402),
             progressStart: .now.addingTimeInterval(-198), pausedRemaining: nil, pausedFraction: nil, more: "+1 more")
    }

    static var sampleUntil: Self {
        Self(timerID: UUID(), title: "Deploy window", caption: "Until 02:00 UTC", endDate: .now.addingTimeInterval(37_242),
             progressStart: nil, pausedRemaining: nil, pausedFraction: nil, more: nil)
    }
}
