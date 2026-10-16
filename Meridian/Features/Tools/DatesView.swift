import MeridianCore
import SwiftData
import SwiftUI

/// Tools › Dates (spec §4.6; boards DatesToday, DatesYearBoundary, DatesReverse,
/// DatesInvalid, DatesNoProfile). One input takes a date, ISO week or fiscal period;
/// every row and note comes from Core's `DatesText`.
struct DatesView: View {
    /// Empty means "today" (decision AC: remembered across launches otherwise).
    @AppStorage("tools.dates.input") private var input = ""
    @State private var sheet: Sheet?

    @Environment(AppState.self) private var appState
    @Query(sort: \SavedFiscalProfile.order) private var saved: [SavedFiscalProfile]

    enum Sheet: Identifiable {
        case add, profiles
        /// Debug only: open the editor on the active profile.
        case editActive
        var id: Self { self }
    }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let today = today(timeline.date)
            let profile = FiscalStore.list(from: saved).active
            let text = input.isEmpty ? today.isoText : input
            let reading = DatesText.read(text, profile: profile, today: today)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    inputBox(text: text, reading: reading, today: today)
                    switch reading {
                    case .empty:
                        EmptyView()
                    case .result(let result):
                        resultContent(result, profile: profile)
                    case .problem(let problem):
                        ProblemBlock(title: problem.title, detail: problem.detail,
                                     fixLabel: problem.fix.map { Text($0.label) },
                                     onFix: problem.fix.map { fix in { input = fix.input } },
                                     onClear: { input = "" })
                        if problem.needsProfile {
                            addProfileCard
                        } else {
                            PlaceholderBox(text: "Week range, day counts and the fiscal mapping appear once the input "
                                           + "is a valid date, ISO week or fiscal period.")
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .add: FiscalEditorSheet(index: nil, initial: FiscalProfile.presets[0], today: today)
                case .profiles: FiscalProfilesSheet(today: today)
                case .editActive:
                    let list = FiscalStore.list(from: saved)
                    FiscalEditorSheet(index: list.activeIndex, initial: list.active ?? FiscalProfile.presets[0], today: today)
                }
            }
        }
        .onAppear {
            if DebugLaunch.tool == "dates", let debugInput = DebugLaunch.input { input = debugInput }
            switch DebugLaunch.screen {
            case "fiscalEditor": sheet = .editActive
            case "fiscalProfiles": sheet = .profiles
            default: break
            }
        }
    }

    /// Spec §4.6: "Today" follows the UTC pill (decision AB).
    private func today(_ live: Date) -> CivilDate {
        ZoneClock.local(appState.now(live), in: appState.isUTCMode ? .utc : .device).date
    }

    private func inputBox(text: String, reading: DatesReading, today: CivilDate) -> some View {
        let isProblem = if case .problem = reading { true } else { false }
        let label = switch reading {
        case .result(let result): result.inputLabel
        case .problem(let problem): problem.inputLabel
        case .empty: ""
        }
        return ToolInputBox(placeholder: today.isoText,
                            text: Binding(get: { text }, set: { input = $0 == today.isoText ? "" : $0 }),
                            isInvalid: isProblem, showsClear: false) {
            if !label.isEmpty {
                Text(label)
                    .meridianFont(.caption)
                    .foregroundStyle(.textSecondary)
                    .fixedSize()
            }
            Button("Today") { input = "" }
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTapTarget)
                .background(.bgElevated, in: .capsule)
                .buttonStyle(.plain)
                .fixedSize()
        }
    }

    @ViewBuilder
    private func resultContent(_ result: DatesResult, profile: FiscalProfile?) -> some View {
        ForEach(result.notesBefore, id: \.text) { note in
            NoteLine(lead: note.lead, text: note.text)
        }
        ForEach(result.sections, id: \.title) { section in
            HStack {
                Text(section.title)
                    .meridianFont(.caption).bold()
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.textSecondary)
                Spacer()
                // Sections about the active fiscal calendar end with its name.
                if let profile, section.title.hasSuffix(" · \(profile.name)") {
                    Button { sheet = .profiles } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text("Change")
                            Image(systemName: "chevron.right").imageScale(.small)
                        }
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                        .frame(minHeight: Spacing.minTapTarget)
                    }
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.top, Spacing.xs)
            ToolCard {
                ForEach(section.rows, id: \.label) { row in
                    CopyRow(label: row.label, value: row.value, copyText: row.copyText, inline: true)
                }
            }
        }
        if result.needsProfile {
            Text("Fiscal")
                .meridianFont(.caption).bold()
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.top, Spacing.xs)
            addProfileCard
        }
        ForEach(result.notesAfter, id: \.text) { note in
            NoteLine(lead: note.lead, text: note.text)
        }
    }

    /// Board DatesNoProfile.
    private var addProfileCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("No fiscal calendar yet. Add one to see fiscal year, quarter, period and week.")
                .meridianFont(.body)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { sheet = .add } label: {
                Label("Add a fiscal calendar", systemImage: "plus")
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: Spacing.minTapTarget)
                    .overlay { Capsule().strokeBorder(Color.fillControl, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }
}

private extension CivilDate {
    /// `2026-10-16`.
    var isoText: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
