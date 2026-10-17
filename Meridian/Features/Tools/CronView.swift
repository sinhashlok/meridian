import MeridianCore
import SwiftData
import SwiftUI

/// Tools › Cron (spec §4.6; boards Cron and CronError): dialect, expression with field
/// names, plain-English description, Evaluate-in zone and the next 5 runs in UTC and on
/// this phone. Wording comes from Core's `CronText`.
struct CronView: View {
    @AppStorage("tools.cron.input") private var input = "0 2 * * *"
    @AppStorage("tools.cron.quartz") private var isQuartz = false
    /// Evaluate in: UTC by default (spec §4.6).
    @AppStorage("tools.cron.zone") private var zoneID = Zone.utc.id
    @FocusState private var isEditing: Bool

    @Environment(AppState.self) private var appState
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]

    private var dialect: CronDialect { isQuartz ? .quartz : .unix }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            let parsed = Result { () throws(CronError) in try CronExpression.parse(input, dialect: dialect) }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    header
                    switch parsed {
                    case .success(let expression):
                        expressionBox(isInvalid: false)
                        valid(expression, now: now)
                    case .failure(let error):
                        expressionBox(isInvalid: true)
                        invalid(error)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            guard DebugLaunch.tool == "cron" else { return }
            if let debugInput = DebugLaunch.input { input = debugInput.replacingOccurrences(of: "_", with: " ") }
            if let zone = DebugLaunch.toolZone { zoneID = zone }
        }
    }

    // MARK: Input

    private var header: some View {
        HStack {
            Text("Expression")
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
            Spacer()
            Menu {
                Picker("Dialect", selection: $isQuartz) {
                    Text("Unix 5-field").tag(false)
                    Text("Quartz 6/7-field").tag(true)
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text(isQuartz ? "Quartz 6/7-field" : "Unix 5-field")
                    Image(systemName: "chevron.down").imageScale(.small)
                }
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTapTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .strokeBorder(Color.separatorLine, lineWidth: 1)
                }
            }
        }
    }

    /// The field, with field names under a valid expression and the key row above the
    /// keyboard (decision AF).
    private func expressionBox(isInvalid: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            TextField(isQuartz ? "0 0 2 ? * MON-FRI" : "0 2 * * *", text: $input)
                .meridianFont(.monoTime)
                .foregroundStyle(.textPrimary)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isEditing)
            if !isInvalid {
                Text(CronText.fieldLabels(dialect))
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(isInvalid ? Color.statusDanger : .separatorLine, lineWidth: isInvalid ? 1.5 : 1)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                ForEach(isQuartz ? ["*", ",", "-", "/", "?", "L", "#"] : ["*", ",", "-", "/"], id: \.self) { key in
                    Button(key) { input += key }
                        .meridianFont(.monoBody)
                        .accessibilityLabel("Insert \(key)")
                }
                Spacer()
                Button("Done") { isEditing = false }
            }
        }
    }

    // MARK: Valid

    @ViewBuilder
    private func valid(_ expression: CronExpression, now: Date) -> some View {
        let zone = Zone(zoneID) ?? .utc
        let zoneName = ToolZoneMenu.name(for: zoneID, zones: zones)
        let runs = expression.nextRuns(after: now, in: zone, count: 5)

        VStack(alignment: .leading, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Runs")
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
                Text(expression.description)
                    .meridianFont(.title)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Color.separatorLine).frame(height: 1)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Evaluate in").meridianFont(.body).foregroundStyle(.textPrimary)
                    Spacer(minLength: Spacing.s)
                    ToolZoneMenu(prefix: "", zoneID: $zoneID, zones: zones)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Evaluate in").meridianFont(.body).foregroundStyle(.textPrimary)
                    ToolZoneMenu(prefix: "", zoneID: $zoneID, zones: zones)
                }
            }
            if let note = CronText.phoneNote(runs: runs, evaluateIn: zone, device: .device) {
                Text(note)
                    .meridianFont(.body)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))

        if let note = CronText.dstNote(runs: runs, zone: zone, zoneName: zoneName) {
            NoteLine(systemImage: "clock.arrow.circlepath", text: note)
        }

        if runs.isEmpty {
            InlineBanner(title: CronText.neverRuns.title, detail: CronText.neverRuns.detail)
        } else {
            HStack {
                ToolCaption(text: "Next \(runs.count) runs")
                Spacer()
                CopyButton(text: CronText.copyText(expression: input.trimmingCharacters(in: .whitespaces),
                                                   description: expression.description, runs: runs, device: .device))
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
                    .frame(minHeight: Spacing.minTapTarget)
                    .buttonStyle(.plain)
            }
            runTable(runs, now: now)
        }
    }

    private func runTable(_ runs: [ScheduledRun], now: Date) -> some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.m, verticalSpacing: 0) {
            GridRow {
                Text("UTC")
                Text(CronText.localHeader(device: .device, at: now)).gridColumnAlignment(.trailing)
            }
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
            .frame(minHeight: Spacing.minTapTarget)
            ForEach(runs, id: \.instant) { run in
                let row = CronText.runRow(run, device: .device)
                Divider().overlay(Color.separatorLine)
                GridRow {
                    Text(row.utc)
                    Text(row.local)
                }
                .meridianFont(.monoBody)
                .foregroundStyle(.textPrimary)
                .frame(minHeight: Spacing.minRowHeight)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.xs)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: Invalid

    @ViewBuilder
    private func invalid(_ error: CronError) -> some View {
        let chips = CronText.fieldChips(input, dialect: dialect, errorField: error.field)
        if !chips.isEmpty {
            HStack(alignment: .top, spacing: Spacing.xs) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    VStack(spacing: Spacing.xxs) {
                        Text(chip.text)
                            .meridianFont(.monoBody)
                            .foregroundStyle(chip.isError ? Color.statusDanger : .textPrimary)
                            .padding(.horizontal, Spacing.xs)
                            .frame(minWidth: 36, minHeight: 36)
                            .background(.bgElevated, in: .rect(cornerRadius: Radius.chip, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                    .strokeBorder(chip.isError ? Color.statusDanger : .clear, lineWidth: 1.5)
                            }
                        HStack(spacing: 2) {
                            if chip.isError { Image(systemName: "arrowtriangle.up.fill").imageScale(.small) }
                            Text(chip.label)
                        }
                        .meridianFont(.caption)
                        .foregroundStyle(chip.isError ? Color.statusDanger : .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        ProblemBlock(title: error.message, detail: CronText.hint(for: error, dialect: dialect) ?? "")
        PlaceholderBox(text: "The description and next runs appear once the expression is valid.")
    }
}
