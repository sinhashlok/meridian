import MeridianCore
import SwiftData
import SwiftUI

/// Sessions (spec §4.5, board Sessions): phase line and cycle dots, the PomodoroRing with
/// the time left and "Ends", the meeting line, then Stop · Pause · Skip. Idle: lengths
/// and Start. Every value comes from Core's `PomodoroSession` / `SessionText`, recomputed
/// from stored instants each second.
struct SessionsView: View {
    /// Mirrors `SessionStore` so changes from Live Activity buttons show at once.
    @AppStorage(SessionStore.sessionKey) private var storedSession = Data()
    @AppStorage(SessionStore.lengthsKey) private var storedLengths = Data()

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    @Query private var records: [SessionRecord]

    @State private var starts = 0

    private var session: PomodoroSession? { try? JSONDecoder().decode(PomodoroSession.self, from: storedSession) }

    var body: some View {
        let session = session
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = appState.now(timeline.date)
            let display: Zone = appState.isUTCMode ? .utc : .device
            ScrollView {
                VStack(spacing: Spacing.sectionGap) {
                    if let session {
                        active(session, now: now, display: display)
                    } else {
                        idle(now: now, display: display)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
            }
            .defaultScrollAnchor(DebugLaunch.startsAtBottom ? .bottom : .top)
            .sensoryFeedback(Haptic.success, trigger: session?.status(at: now) == .done)
        }
        .sensoryFeedback(Haptic.timerStart, trigger: starts)
        .onAppear { SessionStore.applyDebugLaunch(now: appState.now()) }
    }

    // MARK: Running, paused, done

    @ViewBuilder
    private func active(_ session: PomodoroSession, now: Date, display: Zone) -> some View {
        let text = SessionText.card(session, now: now, display: display)
        let status = session.status(at: now)
        let isFocus = session.currentIndex(at: now).map { session.phases[$0].kind == .focus } ?? true

        phaseLine(text.phase, dots: text.dots)

        ring(fraction: session.fraction(at: now), color: ringColor(isFocus: isFocus, isPaused: session.pausedAt != nil),
             hero: status == .done ? "Done" : text.remaining, caption: text.status)

        ForEach(text.notes, id: \.self) { note in
            NoteLine(systemImage: "clock.arrow.circlepath", text: note)
        }

        meetingCard(now: now)

        if status == .done {
            primaryButton("New session", systemImage: "arrow.counterclockwise") {
                SessionStore.finish(at: now, in: context)
            }
        } else {
            controls(isPaused: session.pausedAt != nil)
            Label("Also on Lock Screen and Dynamic Island", systemImage: "iphone")
                .meridianFont(.sub)
                .foregroundStyle(.textTertiary)
        }
    }

    /// `Focus · 1 of 4` over one dot per cycle (done, current in accent, upcoming).
    private func phaseLine(_ phase: String, dots: [CycleDot]) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(phase)
                .meridianFont(.headline)
                .foregroundStyle(.textSecondary)
            HStack(spacing: Spacing.xs) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                    Circle()
                        .fill(dot == .current ? Color.accent : dot == .done ? Color.textSecondary : Color.tintSleep)
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.top, Spacing.m)
    }

    /// Stop · Pause/Resume · Skip (board Sessions). Pause is neutral: Start owns the orange.
    /// At accessibility sizes Pause gets its own row, Stop and Skip go under it.
    @ViewBuilder
    private func controls(isPaused: Bool) -> some View {
        let stop = RoundIconButton(systemImage: "stop.fill", label: "Stop session", fill: .bgSurface, size: 56) {
            SessionStore.finish(at: appState.now(), in: context)
        }
        let pause = Button {
            SessionStore.update { isPaused ? $0.resume(at: appState.now()) : $0.pause(at: appState.now()) }
        } label: {
            Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.pill)
        let skip = RoundIconButton(systemImage: "forward.end.fill", label: "Skip to next phase", fill: .bgSurface,
                                   size: 56) {
            SessionStore.update { $0.skip(at: appState.now()) }
        }
        if typeSize.isAccessibilitySize {
            VStack(spacing: Spacing.m) {
                pause
                HStack { stop; Spacer(); skip }
            }
        } else {
            HStack(spacing: Spacing.m) { stop; pause; skip }
        }
    }

    // MARK: Idle

    @ViewBuilder
    private func idle(now: Date, display: Zone) -> some View {
        let lengths = SessionStore.lengths
        phaseLine("Ready · \(lengths.cycles) \(lengths.cycles == 1 ? "cycle" : "cycles")",
                  dots: Array(repeating: .upcoming, count: lengths.cycles))

        ring(fraction: 1, color: .accent, hero: TimerText.remaining(seconds: lengths.focusMinutes * 60),
             caption: "\(lengths.breakMinutes) min breaks")

        lengthMenus(lengths)
        primaryButton("Start", systemImage: "play.fill") {
            SessionStore.start(at: appState.now())
            starts += 1
        }
        meetingCard(now: now)
        if let today = SessionText.focusedToday(records.map(\.focusRecord), now: now, display: display) {
            Text(today)
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
        }
    }

    /// Decision AW: focus, break and cycles as native menus; remembered.
    private func lengthMenus(_ lengths: SessionLengths) -> some View {
        FlowLayout(spacing: Spacing.xs) {
            lengthMenu("Focus", value: lengths.focusMinutes, options: [15, 25, 45, 50], unit: "min") {
                SessionStore.lengths = SessionLengths(focusMinutes: $0, breakMinutes: lengths.breakMinutes,
                                                      cycles: lengths.cycles)
            }
            lengthMenu("Break", value: lengths.breakMinutes, options: [5, 10, 15], unit: "min") {
                SessionStore.lengths = SessionLengths(focusMinutes: lengths.focusMinutes, breakMinutes: $0,
                                                      cycles: lengths.cycles)
            }
            lengthMenu("Cycles", value: lengths.cycles, options: Array(1...6), unit: "") {
                SessionStore.lengths = SessionLengths(focusMinutes: lengths.focusMinutes,
                                                      breakMinutes: lengths.breakMinutes, cycles: $0)
            }
        }
        // Re-read when the stored lengths change (SessionStore writes UserDefaults directly).
        .id(storedLengths)
    }

    private func lengthMenu(_ title: String, value: Int, options: [Int], unit: String,
                            set: @escaping (Int) -> Void) -> some View {
        let valueText = unit.isEmpty ? "\(value)" : "\(value) \(unit)"
        return Menu {
            Picker(title, selection: Binding(get: { value }, set: set)) {
                ForEach(options, id: \.self) { Text(unit.isEmpty ? "\($0)" : "\($0) \(unit)").tag($0) }
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text("\(title) \(Text(valueText).foregroundStyle(.textPrimary))")
                    .foregroundStyle(.textSecondary)
                Image(systemName: "chevron.down").imageScale(.small).foregroundStyle(.textSecondary)
            }
            .meridianFont(.headline)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: Spacing.minTapTarget)
            .background(.bgSurface, in: .capsule)
        }
        .accessibilityLabel("\(title), \(valueText)")
    }

    // MARK: Shared

    /// The ring with the time inside. Its caption (`Ends 21:28 IST`) sits inside too, or
    /// under the ring at accessibility sizes, where the ring is too small for it.
    @ViewBuilder
    private func ring(fraction: Double, color: Color, hero: String, caption: String) -> some View {
        let captionText = Text(caption)
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
        VStack(spacing: Spacing.s) {
            PomodoroRing(fraction: fraction, color: color) {
                VStack(spacing: Spacing.xxs) {
                    Text(hero)
                        .meridianFont(.timeHero)
                        .foregroundStyle(.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if !typeSize.isAccessibilitySize { captionText }
                }
            }
            if typeSize.isAccessibilitySize { captionText }
        }
        .accessibilityElement(children: .combine)
    }

    /// Focus is accent (running progress, §3.2); a break is `textSecondary` (§4.5); paused
    /// is `textTertiary`, like a paused timer's bar.
    private func ringColor(isFocus: Bool, isPaused: Bool) -> Color {
        isPaused ? .textTertiary : isFocus ? .accent : .textSecondary
    }

    /// Spec §4.5: the next shared window from the Planner's zones; hidden under 2 zones.
    @ViewBuilder
    private func meetingCard(now: Date) -> some View {
        let reference = appState.isUTCMode ? Zone.utc : (zones.first(where: \.isHome)?.zone ?? .utc)
        if let line = MeetingLine.make(zones: zones.compactMap(\.plannerZone), home: reference, now: now) {
            MeetingLineCard(line: line) {
                guard let start = line.start, let day = line.day else { return }
                appState.plannerJump = PlannerJump(day: day, start: start)
                appState.tab = "zones"
            }
        }
    }

    /// The screen's one filled orange button (spec §3.2).
    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .meridianFont(.headline)
                .foregroundStyle(.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(.accent, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
