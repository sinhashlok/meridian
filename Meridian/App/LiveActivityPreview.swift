#if DEBUG
import SwiftUI

/// Debug only (`-MeridianScreen liveActivity`): the Live Activity views at real sizes, so
/// layout can be checked in Simulator screenshots, which don't capture Live Activities.
/// Lock Screen cards are 365pt wide; a red outline means taller than iOS's ~160pt.
struct LiveActivityPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                label("Lock Screen · session")
                lockScreen { SessionLockScreenView(state: .sample) }
                lockScreen { SessionLockScreenView(state: .sampleNoWindow) }
                lockScreen { SessionLockScreenView(state: .samplePaused) }
                label("Lock Screen · timer")
                lockScreen { TimerLockScreenView(state: .sample) }
                lockScreen { TimerLockScreenView(state: .sampleUntil) }
                label("Island · expanded")
                island {
                    VStack(alignment: .leading, spacing: 12) {
                        SessionExpandedTop(state: .sample)
                        SessionExpandedBottom(state: .sample)
                    }
                }
                island {
                    VStack(alignment: .leading, spacing: 12) {
                        TimerExpandedTop(state: .sample)
                        TimerExpandedBottom(state: .sample)
                    }
                }
                label("Island · compact")
                compact(leading: SessionRing(state: .sample), countdownEnd: SessionActivityAttributes.ContentState.sample.endDate)
            }
            .padding(.vertical, 24)
        }
        .defaultScrollAnchor(DebugLaunch.startsAtBottom ? .bottom : .top)
        .background(Color(white: 0.32))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
    }

    private func lockScreen(@ViewBuilder _ content: () -> some View) -> some View {
        let view = content()
        return MeasuredCard(limit: 160) { view }
            .frame(width: 365)
            .background(Color.bgBase, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func island(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 22)
            .padding(.top, 44)                 // the camera sits above the content
            .padding(.bottom, 18)
            .frame(width: 371)
            .background(.black, in: .rect(cornerRadius: 44, style: .continuous))
    }

    private func compact(leading: some View, countdownEnd: Date?) -> some View {
        HStack {
            leading.frame(width: 22, height: 22)
            Spacer()
            LiveCountdown(end: countdownEnd, paused: nil)
                .monospacedDigit().foregroundStyle(.accent)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(width: 250, height: 37)
        .background(.black, in: .capsule)
    }
}

/// Shows the content's natural height and outlines it red past `limit`.
private struct MeasuredCard<Content: View>: View {
    let limit: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var height: CGFloat = 0

    var body: some View {
        content()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .overlay(alignment: .topTrailing) {
                Text("\(Int(height.rounded()))pt")
                    .font(.caption2.monospacedDigit()).foregroundStyle(height > limit ? .red : .green)
                    .padding(6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(height > limit ? Color.red : .clear, lineWidth: 2)
            }
    }
}
#endif
