import MeridianCore
import SwiftUI

/// Timer › Stopwatch (spec §4.4, decision AP): centiseconds, Lap/Reset and Start/Stop,
/// laps newest first with fastest/slowest marked from 3 laps, Copy CSV. The Core
/// `Stopwatch` (start instant + millisecond totals) is saved as JSON on every change,
/// so it survives the app being killed.
struct StopwatchView: View {
    @AppStorage("stopwatch.state") private var stored = Data()
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var laps = 0
    @State private var starts = 0

    private var watch: Stopwatch {
        (try? JSONDecoder().decode(Stopwatch.self, from: stored)) ?? Stopwatch()
    }

    var body: some View {
        let watch = watch
        let hasStarted = watch.isRunning || watch.accumulatedMs > 0
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                ticking(watch) { now in
                    let elapsed = StopwatchText.time(ms: watch.elapsedMs(at: now))
                    Text(elapsed)
                        .meridianFont(.timeHero)
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Elapsed \(elapsed)")
                }
                .padding(.top, Spacing.xl)

                buttons(watch, hasStarted: hasStarted)

                if hasStarted {
                    lapList(watch)
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.sectionGap)
        }
        .sensoryFeedback(Haptic.lap, trigger: laps)
        .sensoryFeedback(Haptic.timerStart, trigger: starts)
        .onAppear(perform: applyDebugLaunch)
    }

    /// Redraws `content` up to 30 times a second while running, never while stopped.
    /// Only the hero time and the lap in progress use it; finished laps don't change.
    private func ticking(_ watch: Stopwatch, @ViewBuilder content: @escaping (Date) -> some View) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !watch.isRunning)) { timeline in
            content(appState.now(timeline.date))
        }
    }

    // MARK: Buttons

    private func buttons(_ watch: Stopwatch, hasStarted: Bool) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.s)) : AnyLayout(HStackLayout(spacing: Spacing.s))
        return layout {
            if watch.isRunning {
                pill("Lap", systemImage: "flag", filled: false) {
                    change { $0.lap(at: appState.now()) }
                    laps += 1
                }
                pill("Stop", systemImage: "pause.fill", filled: false) { change { $0.stop(at: appState.now()) } }
            } else {
                pill("Reset", systemImage: "arrow.counterclockwise", filled: false) { change { $0.reset() } }
                    .disabled(!hasStarted)
                // The screen's one filled orange button (spec §3.2).
                pill(hasStarted ? "Resume" : "Start", systemImage: "play.fill", filled: true) {
                    change { $0.start(at: appState.now()) }
                    starts += 1
                }
            }
        }
    }

    private func pill(_ title: String, systemImage: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .meridianFont(.headline)
                .foregroundStyle(filled ? Color.onAccent : Color.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight)
                .background(filled ? Color.accent : Color.bgElevated, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: Laps

    private func lapList(_ watch: Stopwatch) -> some View {
        let completed = watch.laps
        let marks = StopwatchText.marks(completed)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            let count = Text(completed.isEmpty ? "No laps yet" : completed.count == 1 ? "1 lap" : "\(completed.count) laps")
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
            RowOrStack {
                count
                if !completed.isEmpty { copyButton(completed) }
            }

            VStack(spacing: 0) {
                if !typeSize.isAccessibilitySize { LapColumnsHeader() }
                ticking(watch) { now in
                    LapRow(title: "Lap \(completed.count + 1)", split: watch.currentLapMs(at: now),
                           total: watch.elapsedMs(at: now), mark: nil)
                }
                ForEach(completed.reversed(), id: \.number) { lap in
                    Rectangle().fill(Color.separatorLine).frame(height: 1).padding(.leading, Spacing.m)
                    LapRow(title: "Lap \(lap.number)", split: lap.splitMs, total: lap.totalMs, mark: marks[lap.number])
                }
            }
            .background(.bgSurface)
            .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        }
    }

    /// Copy CSV (spec §4.4).
    private func copyButton(_ completed: [Lap]) -> some View {
        CopyButton(text: StopwatchText.csv(completed), title: "Copy CSV")
            .buttonStyle(.pill)
    }

    // MARK: State

    private func change(_ update: (inout Stopwatch) -> Void) {
        var watch = watch
        update(&watch)
        stored = (try? JSONEncoder().encode(watch)) ?? stored
    }

    /// `-MeridianStopwatch demo`: running 3 min 30 s with laps at 1:02.34, 2:00.00 and
    /// 3:20.50 (fastest lap 2, slowest lap 3), relative to the (frozen) clock.
    private func applyDebugLaunch() {
        guard DebugLaunch.stopwatch == "demo" else { return }
        let start = appState.now().addingTimeInterval(-210)
        var demo = Stopwatch()
        demo.start(at: start)
        for offset in [62.345, 120, 200.5] { demo.lap(at: start.addingTimeInterval(offset)) }
        stored = (try? JSONEncoder().encode(demo)) ?? stored
    }
}

/// "Split · Total" over the value columns, each as wide as an `MM:SS.cc` value.
private struct LapColumnsHeader: View {
    var body: some View {
        HStack(spacing: Spacing.s) {
            Spacer(minLength: 0)
            column("Split")
            column("Total")
        }
        .meridianFont(.caption)
        .foregroundStyle(.textTertiary)
        .padding(.horizontal, Spacing.m)
        .padding(.top, Spacing.s)
        .accessibilityHidden(true)
    }

    private func column(_ title: String) -> some View {
        ZStack(alignment: .leading) {
            Text("00:00.00").meridianFont(.monoCaption).hidden()
            Text(title)
        }
    }
}

/// One lap: name (+ Fastest/Slowest tag and glyph), split and total in aligned mono
/// columns. Marked laps get the `bgElevated` fill (spec §4.4: fill + tag + glyph).
private struct LapRow: View {
    let title: String
    let split: Int64
    let total: Int64
    let mark: LapMark?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s))
        layout {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .meridianFont(.sub)
                    .foregroundStyle(.textPrimary)
                if let mark {
                    Label(mark == .fastest ? "Fastest" : "Slowest",
                          systemImage: mark == .fastest ? "hare" : "tortoise")
                        .meridianFont(.caption)
                        .foregroundStyle(.textPrimary)
                }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, alignment: .leading)
            value(split, label: "split", color: .textPrimary)
            value(total, label: "total", color: .textSecondary)
        }
        .padding(.horizontal, Spacing.m)
        .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget, alignment: .leading)
        .padding(.vertical, Spacing.xxs)
        .background(mark == nil ? Color.clear : Color.bgElevated)
        .accessibilityElement(children: .combine)
    }

    /// Stacked at accessibility sizes, where the column header is gone: `Split 00:09.50`.
    private func value(_ ms: Int64, label: String, color: Color) -> some View {
        Text("\(Text(typeSize.isAccessibilitySize ? label.capitalized + " " : "").font(.footnote))\(StopwatchText.time(ms: ms))")
            .meridianFont(.monoCaption)
            .foregroundStyle(color)
            .accessibilityLabel("\(label) \(StopwatchText.time(ms: ms))")
    }
}
