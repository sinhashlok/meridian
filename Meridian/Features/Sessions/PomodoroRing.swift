import SwiftUI

/// PomodoroRing (spec §4.5, board Sessions): a track with the remaining fraction drawn
/// clockwise from 12 o'clock, in `color` (focus, break and paused colours: SessionsView).
struct PomodoroRing<Content: View>: View {
    /// 1 → 0 as the phase runs.
    let fraction: Double
    let color: Color
    @ViewBuilder var content: () -> Content

    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.bgSurface, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
            content()
                .padding(lineWidth * 2)
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
    }
}
