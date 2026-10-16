import MeridianCore
import SwiftData
import SwiftUI

/// Tools › Epoch (spec §4.6; boards Epoch, EpochInvalid, EpochRange, EpochAmbiguous,
/// EpochZoneless). Digits are an epoch in s/ms/µs/ns; a date-time goes the other way.
/// Every value and message comes from Core's `EpochText`.
struct EpochView: View {
    /// Remembered across launches (decision AC).
    @AppStorage("tools.epoch.input") private var input = ""
    /// Interpret-as zone for zone-less date-times; UTC by default (spec §4.6).
    @AppStorage("tools.epoch.zone") private var zoneID = Zone.utc.id
    @State private var unitOverride: EpochUnit?
    @State private var occurrence: Occurrence = .first

    @Environment(AppState.self) private var appState
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Timestamp")
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                    switch EpochText.kind(of: input) {
                    case .empty:
                        ToolInputBox(placeholder: "1792060800000", text: $input)
                        controls(chip: nil, now: now)
                        hint
                    case .epoch:
                        epochContent(now: now)
                    case .dateTime:
                        dateTimeContent(now: now)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: input) {
            unitOverride = nil
            occurrence = .first
        }
        .onAppear {
            guard DebugLaunch.tool == "epoch" else { return }
            if let debugInput = DebugLaunch.input { input = debugInput }
            if let zone = DebugLaunch.toolZone { zoneID = zone }
        }
    }

    // MARK: Epoch digits

    @ViewBuilder
    private func epochContent(now: Date) -> some View {
        let problem = EpochText.problem(in: input, unit: unitOverride)
        ToolInputBox(placeholder: "1792060800000", text: $input, isInvalid: problem != nil)
        // A bad character makes the digit count meaningless, so the chip hides then (board EpochInvalid).
        let chip = problem?.characterIndex == nil ? EpochText.unitChip(for: input, unit: unitOverride) : nil
        controls(chip: chip, now: now)

        if let problem {
            if let index = problem.characterIndex { characterStrip(index: index) }
            ProblemBlock(title: problem.title, detail: problem.detail,
                         fixLabel: problem.fix.map { Text("Replace with \(Text($0.label).monospaced())") },
                         onFix: problem.fix.map { fix in { input = fix.input } },
                         onClear: problem.characterIndex == nil ? nil : { input = "" })
            if problem.readings.isEmpty {
                PlaceholderBox(text: "UTC, local, ISO 8601, relative time and Unix seconds appear once the input "
                               + "is a valid timestamp.")
            } else {
                ToolCaption(text: "Lengths we read")
                ToolCard {
                    ForEach(problem.readings, id: \.digits) { reading in
                        HStack(spacing: Spacing.m) {
                            Text("\(reading.digits)").meridianFont(.monoBody).foregroundStyle(.textPrimary)
                                .frame(minWidth: 28, alignment: .leading)
                            Text(reading.unit.rawValue).meridianFont(.sub).foregroundStyle(.textPrimary)
                            Spacer(minLength: Spacing.s)
                            Text(reading.dateText).meridianFont(.monoBody).foregroundStyle(.textSecondary)
                                .fixedSize()
                        }
                        .padding(.horizontal, Spacing.m)
                        .frame(minHeight: Spacing.minRowHeight)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        } else if let parsed = try? EpochParser.parse(input, as: unitOverride) {
            if let note = EpochText.ambiguity(parsed, input: input, now: now) {
                InlineBanner(title: note.title, detail: note.detail, systemImage: "questionmark.circle")
                readingCards(selected: parsed.unit)
            } else {
                hint
            }
            results(parsed.value, precision: parsed.unit, isoZone: .utc, now: now)
        }
    }

    /// Unit chip (with the override menu), Paste and Now.
    private func controls(chip: (digits: String, unit: String)?, now: Date) -> some View {
        let tooLong = chip?.unit == "no unit fits"
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) { unitMenu(chip, tooLong: tooLong); Spacer(minLength: 0); pasteAndNow(now) }
            VStack(alignment: .leading, spacing: Spacing.xs) { unitMenu(chip, tooLong: tooLong); pasteAndNow(now) }
        }
    }

    @ViewBuilder
    private func unitMenu(_ chip: (digits: String, unit: String)?, tooLong: Bool) -> some View {
        if let chip {
            Menu {
                Picker("Read as", selection: $unitOverride) {
                    Text("Automatic").tag(EpochUnit?.none)
                    ForEach(EpochUnit.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(EpochUnit?.some($0)) }
                }
            } label: {
                // Side by side; stacked when it can't fit (large text), so words never break.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.xxs) { chipParts(chip, tooLong: tooLong) }
                    VStack(alignment: .leading, spacing: 2) { chipParts(chip, tooLong: tooLong) }
                }
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: Spacing.minTapTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .strokeBorder(tooLong ? Color.statusDanger : .separatorLine, lineWidth: 1)
                }
            }
            .disabled(tooLong)
            .accessibilityLabel("\(chip.digits), read as \(chip.unit)")
        }
    }

    @ViewBuilder
    private func chipParts(_ chip: (digits: String, unit: String), tooLong: Bool) -> some View {
        Text(chip.digits)
            .meridianFont(.monoCaption)
            .foregroundStyle(tooLong ? Color.statusDanger : .textSecondary)
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "arrow.right").imageScale(.small).foregroundStyle(.textSecondary)
            Text(chip.unit)
                .meridianFont(.sub)
                .fontWeight(tooLong ? .regular : .semibold)
                .foregroundStyle(tooLong ? Color.textSecondary : .textPrimary)
            if !tooLong {
                Image(systemName: "chevron.down").imageScale(.small).foregroundStyle(.textSecondary)
            }
        }
    }

    private func pasteAndNow(_ now: Date) -> some View {
        HStack(spacing: Spacing.xs) {
            PasteButton(payloadType: String.self) { strings in
                input = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? input
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.iconOnly)                   // keeps the chip, Paste and Now on one line
            .tint(.bgElevated)
            .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
            Button("Now") { insertNow(now) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.textPrimary)
                .accessibilityHint("Inserts the current epoch")
        }
        .controlSize(.regular)
        .frame(minHeight: Spacing.minTapTarget)
    }

    /// Decision AB: the current epoch in the unit shown, seconds when nothing is shown.
    private func insertNow(_ now: Date) {
        let unit = (try? EpochParser.parse(input, as: unitOverride))?.unit ?? unitOverride ?? .seconds
        let interval = now.timeIntervalSince1970
        let seconds = Int64(interval.rounded(.down))
        let value = EpochValue(seconds: seconds, nanoseconds: Int32((interval - Double(seconds)) * 1_000_000_000))
        if let count = value.count(in: unit) { input = String(count) }
    }

    private var hint: some View {
        Text("Epoch in s, ms, µs or ns, or an ISO 8601 date.")
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
    }

    /// The input with the bad character marked, so a letter O can't hide among zeros.
    private func characterStrip(index: Int) -> some View {
        let characters = Array(input)
        var text = AttributedString()
        for (offset, character) in characters.enumerated() {
            var piece = AttributedString(String(character))
            if offset + 1 == index {
                piece.foregroundColor = .statusDanger
                piece.underlineStyle = .single
            }
            text += piece
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .meridianFont(.monoTime)
                .tracking(6)
                .foregroundStyle(.textPrimary)
            Text("Character \(index)")
                .meridianFont(.monoCaption)
                .foregroundStyle(.statusDanger)
        }
        .padding(.horizontal, Spacing.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Character \(index) is \(String(characters[index - 1]))")
    }

    /// Both readings of an ambiguous length; tapping one overrides the unit.
    private func readingCards(selected: EpochUnit) -> some View {
        return HStack(spacing: Spacing.s) {
            ForEach(EpochText.readings(of: input, units: EpochText.candidateUnits(for: input)), id: \.unit) { reading in
                let isSelected = reading.unit == selected
                Button { unitOverride = reading.unit } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reading.unit.rawValue.capitalized).meridianFont(.headline).foregroundStyle(.textPrimary)
                            Text(reading.dateText).meridianFont(.monoBody).foregroundStyle(.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if isSelected { Image(systemName: "checkmark").foregroundStyle(.textPrimary) }
                    }
                    .padding(Spacing.s)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight, alignment: .leading)
                    .background(.bgSurface, in: .rect(cornerRadius: Radius.row, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                            .strokeBorder(isSelected ? Color.textPrimary : .separatorLine, lineWidth: isSelected ? 1.5 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: Date-time

    @ViewBuilder
    private func dateTimeContent(now: Date) -> some View {
        ToolInputBox(placeholder: "2026-10-15T10:40:00Z", text: $input)
        switch parseDateTime() {
        case .zoned(let value):
            Text("Date & time · zone given")
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
            results(value, precision: .nanoseconds, isoZone: .utc, now: now)
        case .zoneless(let local):
            zonelessContent(local, now: now)
        case .invalid:
            ProblemBlock(title: "Not a date-time we can read",
                         detail: "Write it as 2026-10-15T10:40:00Z, or without a zone: 2026-10-25 01:30.",
                         onClear: { input = "" })
            PlaceholderBox(text: "UTC, local, ISO 8601, relative time and Unix seconds appear once the input "
                           + "is a valid timestamp.")
        }
    }

    private enum DateTimeInput {
        case zoned(EpochValue)
        case zoneless(LocalInput)
        case invalid
    }

    private func parseDateTime() -> DateTimeInput {
        do {
            return .zoned(try EpochParser.parseISO8601(input))
        } catch .missingZone {
            return (try? EpochParser.parseLocalDateTime(input)).map(DateTimeInput.zoneless) ?? .invalid
        } catch {
            return .invalid
        }
    }

    @ViewBuilder
    private func zonelessContent(_ local: LocalInput, now: Date) -> some View {
        let zone = Zone(zoneID) ?? .utc
        let reading = EpochText.zoneless(local, in: zone, zoneName: ToolZoneMenu.name(for: zoneID, zones: zones))
        ViewThatFits(in: .horizontal) {
            HStack {
                zonelessLabel
                Spacer(minLength: Spacing.xs)
                ToolZoneMenu(prefix: "Interpret as", zoneID: $zoneID, zones: zones)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                zonelessLabel
                ToolZoneMenu(prefix: "Interpret as", zoneID: $zoneID, zones: zones)
            }
        }
        if reading.options.count == 2 {
            HStack(spacing: Spacing.s) {
                ForEach(reading.options, id: \.title) { option in
                    occurrenceCard(option, isSelected: option.occurrence == occurrence)
                }
            }
        }
        if let note = reading.note(for: occurrence) {
            NoteLine(systemImage: "clock.arrow.circlepath", text: note)
        }
        let precision: EpochUnit = switch local.fractionDigits {
        case 0: .seconds
        case 1...3: .milliseconds
        case 4...6: .microseconds
        default: .nanoseconds
        }
        results(reading.option(for: occurrence).value, precision: precision, isoZone: zone, now: now)
    }

    private var zonelessLabel: some View {
        Text("Date & time · no zone")
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
    }

    private func occurrenceCard(_ option: ZonelessOption, isSelected: Bool) -> some View {
        Button { occurrence = option.occurrence } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).meridianFont(.headline).foregroundStyle(.textPrimary)
                    Text(option.detail).meridianFont(.monoCaption).foregroundStyle(.textSecondary)
                }
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark").foregroundStyle(.textPrimary) }
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight, alignment: .leading)
            .background(.bgSurface, in: .rect(cornerRadius: Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .strokeBorder(isSelected ? Color.textPrimary : .separatorLine, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Results

    @ViewBuilder
    private func results(_ value: EpochValue, precision: EpochUnit, isoZone: Zone, now: Date) -> some View {
        ToolCard {
            ForEach(EpochText.rows(value, precision: precision, local: .device, isoZone: isoZone, now: now), id: \.label) { row in
                CopyRow(label: row.label, value: row.value, copyText: row.copyText)
            }
        }
        let others = zones.filter { $0.ianaID != Zone.device.id }.compactMap { saved in saved.zone.map { (saved.name, $0) } }
        if value.isInISORange, !others.isEmpty {
            ToolCaption(text: "In your zones")
            ToolCard {
                ForEach(others, id: \.0) { name, zone in
                    HStack {
                        Text(name).meridianFont(.body).foregroundStyle(.textPrimary)
                        Spacer(minLength: Spacing.s)
                        Text(ZoneClock.timeWithAbbreviation(value.date, in: zone))
                            .meridianFont(.monoBody)
                            .foregroundStyle(.textPrimary)
                    }
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: Spacing.minRowHeight)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
