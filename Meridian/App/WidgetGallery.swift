#if DEBUG
import MeridianCore
import SwiftData
import SwiftUI

/// Debug only (`-MeridianScreen widgets`): every widget and accessory at real sizes, from the
/// same snapshot the widgets get, so layouts can be checked in Simulator screenshots.
/// Full colour only: tinted and clear modes need the phone or an Xcode widget preview.
/// Sizes are the boards' (iPhone Pro Max class); Home Screen widgets get 16pt margins.
struct WidgetGallery: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    @Query(sort: \SavedJob.order) private var jobs: [SavedJob]

    var body: some View {
        let snapshot = WidgetSync.snapshot(zones: zones, jobs: jobs, isUTCMode: appState.isUTCMode)
        let now = appState.now()
        let clock = WidgetText.clock(snapshot, now: now)
        let jobsText = WidgetText.jobs(snapshot, now: now, device: .device)

        ScrollView {
            VStack(spacing: 18) {
                label("Small · UTC and home  ·  Small · Next job")
                HStack(spacing: 24) {
                    home(width: 170, height: 170) { ClockWidgetView(text: clock) }
                    home(width: 170, height: 170) { JobsSmallView(jobs: jobsText) }
                }
                label("Medium · Planner")
                home(width: 364, height: 170) { PlannerWidgetView(text: WidgetText.planner(snapshot, now: now)) }
                label("Medium · Next jobs")
                home(width: 364, height: 170) { JobsMediumView(jobs: jobsText) }
                label("Large · Next jobs")
                home(width: 364, height: 382) { JobsLargeView(jobs: jobsText) }
                label("Lock Screen · inline, circular, rectangular")
                lockScreen {
                    VStack(spacing: 12) {
                        NextJobInlineView(jobs: jobsText)
                        UTCInlineView(now: now)
                        HStack(spacing: 12) {
                            circular { NextJobCircularView(jobs: jobsText) }
                            circular { UTCCircularView(text: clock) }
                            NextJobRectangularView(jobs: jobsText)
                                .frame(width: 172, height: 76)
                        }
                    }
                }
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

    /// A Home Screen widget: clipped like the real one, so overflow shows as cut-off.
    private func home(width: CGFloat, height: CGFloat, @ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.bgBase)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }

    private func lockScreen(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .foregroundStyle(.white)
            .padding(16)
            .frame(width: 380)
            .background(.black, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func circular(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(width: 72, height: 72)
            .background(.white.opacity(0.15), in: .circle)
            .clipShape(.circle)
    }
}
#endif
