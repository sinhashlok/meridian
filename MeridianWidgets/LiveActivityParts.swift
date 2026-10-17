import SwiftUI

// Pieces both Live Activities draw. Live Activities can't run our clock code, so running
// countdowns use the system's self-updating `Text(timerInterval:)` and
// `ProgressView(timerInterval:)` (decision AK: they print `6:42`, not `06:42`); paused
// ones show the frozen values the app sent.

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

/// A draining bar (linear) or ring (circular): live from `start` to `end`, else the
/// paused fraction, else nothing (Until timers have no bar).
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
        case .bar: view.tint(tint)
        case .ring: view.progressViewStyle(.circular).tint(tint)
        }
    }
}
