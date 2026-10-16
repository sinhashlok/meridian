import MeridianCore
import SwiftData
import SwiftUI

/// Fiscal calendar sheet (spec §4.6; boards FiscalEditor and FiscalEditorMonths).
/// Edits a Core `FiscalProfile` field by field; the preview below updates live.
struct FiscalEditorSheet: View {
    /// `nil` adds a new profile.
    let index: Int?
    let initial: FiscalProfile
    let today: CivilDate

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedFiscalProfile.order) private var saved: [SavedFiscalProfile]

    @State private var name = ""
    @State private var startMonth = 4
    @State private var weekStart = 1
    @State private var isWeekBased = false
    @State private var week1: FiscalProfile.Week1Rule = .containsYearStart
    @State private var pattern: FiscalProfile.Pattern = .p445
    @State private var yearEnd: FiscalProfile.YearEndRule = .nearestMonthEnd
    @State private var naming: FiscalProfile.Naming = .short
    @State private var saves = 0

    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August",
                                 "September", "October", "November", "December"]
    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    private var profile: FiscalProfile {
        FiscalProfile(name: name.trimmingCharacters(in: .whitespaces), startMonth: startMonth, weekStart: weekStart,
                      basis: isWeekBased ? .weekBased(pattern: pattern, yearEnd: yearEnd) : .calendarMonths(week1: week1),
                      naming: naming)
    }

    var body: some View {
        let count = FiscalStore.list(from: saved).profiles.count + (index == nil ? 1 : 0)
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .meridianFont(.body)
                } header: {
                    Text("Name · \(min(count, FiscalProfileList.maximum)) of \(FiscalProfileList.maximum) profiles")
                }

                Section {
                    Picker("Year starts", selection: $startMonth) {
                        ForEach(1...12, id: \.self) { Text(Self.months[$0 - 1]).tag($0) }
                    }
                    .pickerStyle(.menu)
                    LabeledContent("Basis") {
                        Picker("Basis", selection: $isWeekBased) {
                            Text("Calendar months").tag(false)
                            Text("Week-based").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    if !isWeekBased { weekStartPicker }
                }

                if isWeekBased {
                    Section {
                        LabeledContent("Pattern") {
                            HStack(spacing: Spacing.xs) {
                                ForEach([FiscalProfile.Pattern.p445, .p454, .p544], id: \.self) { option in
                                    patternChip(option)
                                }
                            }
                        }
                        weekStartPicker
                        Picker("Year ends", selection: $yearEnd) {
                            Text(FiscalEditorText.yearEndLabel(.nearestMonthEnd, startMonth: startMonth, weekStart: weekStart))
                                .tag(FiscalProfile.YearEndRule.nearestMonthEnd)
                            Text(FiscalEditorText.yearEndLabel(.lastInMonth, startMonth: startMonth, weekStart: weekStart))
                                .tag(FiscalProfile.YearEndRule.lastInMonth)
                        }
                        .pickerStyle(.menu)
                        // Decision Z: the only rule Core supports.
                        LabeledContent("53rd week", value: "Last period")
                    } footer: {
                        if let note = FiscalEditorText.next53WeekYear(profile, today: today) {
                            NoteLine(lead: note.lead, text: note.text)
                                .padding(.top, Spacing.xs)
                        }
                    }
                } else {
                    let previews = FiscalEditorText.week1Previews(profile, today: today)
                    Section("Week 1") {
                        week1Option(.containsYearStart, title: "Week containing the year start",
                                    detail: previews.containing)
                        week1Option(.startsOnYearStart, title: "Starts on the year start",
                                    note: "First week may be short.", detail: previews.startsOn)
                    }
                }

                Section {
                    let names = FiscalEditorText.yearNames(startMonth: startMonth, today: today)
                    LabeledContent("Year name") {
                        Picker("Year name", selection: $naming) {
                            Text(names.short).tag(FiscalProfile.Naming.short)
                            Text(names.long).tag(FiscalProfile.Naming.long)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }

                Section {
                    let preview = FiscalEditorText.thisYear(profile, today: today)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This year").meridianFont(.sub).foregroundStyle(.textSecondary)
                        Text(preview.title).meridianFont(.monoBody).bold().foregroundStyle(.textPrimary)
                        Text(preview.range).meridianFont(.monoCaption).foregroundStyle(.textSecondary)
                        Text(preview.today).meridianFont(.sub).foregroundStyle(.textSecondary)
                    }
                    .padding(.vertical, Spacing.xxs)
                    .accessibilityElement(children: .combine)
                }
            }
            .scrollContentBackground(.hidden)
            // Menu values and Cancel are not "on" states: neutral, not orange (spec §3.2).
            .tint(.textPrimary)
            .navigationTitle("Fiscal calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // The screen's one filled orange button (spec §3.2).
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                        .foregroundStyle(.onAccent)
                        .disabled(profile.name.isEmpty)
                }
            }
            .sensoryFeedback(Haptic.success, trigger: saves)
        }
        .presentationBackground(.bgElevated)
        .onAppear(perform: load)
    }

    private var weekStartPicker: some View {
        Picker("Week starts on", selection: $weekStart) {
            ForEach(1...7, id: \.self) { Text(Self.weekdays[$0 - 1]).tag($0) }
        }
        .pickerStyle(.menu)
    }

    private func patternChip(_ option: FiscalProfile.Pattern) -> some View {
        let label = switch option {
        case .p445: "4-4-5"
        case .p454: "4-5-4"
        case .p544: "5-4-4"
        }
        let isSelected = pattern == option
        return Button { pattern = option } label: {
            Text(label)
                .meridianFont(.monoCaption).bold()
                .foregroundStyle(isSelected ? Color.textPrimary : .textSecondary)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: Spacing.minTapTarget)
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.textPrimary : .fillControl, lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func week1Option(_ rule: FiscalProfile.Week1Rule, title: String, note: String? = nil,
                             detail: String) -> some View {
        let isSelected = week1 == rule
        return Button { week1 = rule } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                // Selected radio is an "on" state, so it may be orange (spec §3.2).
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accent : .fillControl)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).meridianFont(.body).foregroundStyle(.textPrimary)
                    if let note { Text(note).meridianFont(.sub).foregroundStyle(.textSecondary) }
                    Text(detail).meridianFont(.monoCaption).foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func load() {
        name = initial.name
        startMonth = initial.startMonth
        weekStart = initial.weekStart
        naming = initial.naming
        switch initial.basis {
        case .calendarMonths(let rule):
            isWeekBased = false
            week1 = rule
        case .weekBased(let p, let end):
            isWeekBased = true
            pattern = p
            yearEnd = end
        }
    }

    private func save() {
        let profile = profile
        FiscalStore.update(saved, in: context) { list in
            if let index {
                list.replace(at: index, with: profile)
            } else if list.add(profile) {
                list.activate(at: list.profiles.count - 1)
            }
        }
        saves += 1
        dismiss()
    }
}

/// "Change ›" from Dates: pick the active profile, edit, delete or add (max 3).
struct FiscalProfilesSheet: View {
    let today: CivilDate

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedFiscalProfile.order) private var saved: [SavedFiscalProfile]
    @State private var editing: EditTarget?

    struct EditTarget: Identifiable {
        let index: Int?
        let profile: FiscalProfile
        var id: String { "\(index ?? -1)-\(profile.name)" }
    }

    var body: some View {
        let list = FiscalStore.list(from: saved)
        NavigationStack {
            List {
                Section {
                    ForEach(Array(list.profiles.enumerated()), id: \.offset) { index, profile in
                        HStack {
                            Button {
                                FiscalStore.update(saved, in: context) { $0.activate(at: index) }
                            } label: {
                                HStack(spacing: Spacing.s) {
                                    Image(systemName: index == list.activeIndex ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(index == list.activeIndex ? Color.accent : .fillControl)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name).meridianFont(.headline).foregroundStyle(.textPrimary)
                                        Text(FiscalEditorText.thisYear(profile, today: today).title)
                                            .meridianFont(.sub).foregroundStyle(.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(index == list.activeIndex ? .isSelected : [])
                            Button("Edit") { editing = EditTarget(index: index, profile: profile) }
                                .foregroundStyle(.accentText)
                                .frame(minHeight: Spacing.minTapTarget)
                        }
                        .listRowBackground(Color.bgSurface)
                    }
                    .onDelete { offsets in
                        FiscalStore.update(saved, in: context) { list in
                            for offset in offsets.sorted(by: >) { list.remove(at: offset) }
                        }
                    }
                } footer: {
                    Text("Up to \(FiscalProfileList.maximum) calendars. The checked one is used in Dates.")
                }

                if !list.isFull {
                    Section("Add") {
                        ForEach(FiscalProfile.presets + [FiscalProfile.custom], id: \.name) { preset in
                            Button {
                                editing = EditTarget(index: nil, profile: preset)
                            } label: {
                                Label(preset == FiscalProfile.custom ? "Custom" : preset.name, systemImage: "plus")
                                    .foregroundStyle(.textPrimary)
                                    .frame(minHeight: Spacing.minTapTarget)
                            }
                            .listRowBackground(Color.bgSurface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Fiscal calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .sheet(item: $editing) { target in
                FiscalEditorSheet(index: target.index, initial: target.profile, today: today)
            }
        }
        .presentationBackground(.bgElevated)
    }
}
