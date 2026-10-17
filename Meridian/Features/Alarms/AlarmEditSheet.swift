import MeridianCore
import SwiftData
import SwiftUI

/// New / Edit alarm (spec §4.2, board AlarmEdit): wheel, Time zone with its time on this
/// phone, When clocks change (Keep <zone> time | Keep UTC time) with a live DSTNote,
/// Repeat, Label, Sound, Snooze, and Delete for a saved alarm.
struct AlarmEditSheet: View {
    let original: ClockAlarm?
    let onSave: (ClockAlarm) -> Void
    let onDelete: (() -> Void)?

    @State private var draft: ClockAlarm
    @State private var keepsUTC: Bool
    @State private var isPickingZone = false

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    init(original: ClockAlarm?, onSave: @escaping (ClockAlarm) -> Void, onDelete: (() -> Void)?) {
        self.original = original
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: original ?? ClockAlarm(time: ClockTime(7, 0), zoneID: nil, policy: .keepZone,
                                                            repeatDays: [], label: "", snoozeMinutes: 9, isOn: true))
        if case .keepUTC = original?.policy { _keepsUTC = State(initialValue: true) } else { _keepsUTC = State(initialValue: false) }
    }

    private static let snoozeChoices = [5, 9, 10, 15]

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let now = appState.now(timeline.date)
                let device = Zone.device
                // What Save would store, so every line below describes exactly that.
                let preview = draft.saving(keepsUTC: keepsUTC, now: now, device: device)

                Form {
                    Section {
                        ClockTimePicker(title: "Time", time: $draft.time)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }

                    Section {
                        LabeledContent("Time zone") {
                            Button { isPickingZone = true } label: {
                                HStack(spacing: Spacing.xxs) {
                                    Text(zoneName)
                                    Image(systemName: "chevron.right").imageScale(.small)
                                }
                            }
                            .buttonStyle(.pill)
                        }
                    } footer: {
                        if let line = AlarmText.localEquivalent(preview, now: now, device: device) {
                            Text(line).meridianFont(.sub).foregroundStyle(.textSecondary)
                        }
                    }

                    if let choices = AlarmText.policyChoices(preview, now: now, device: device) {
                        Section {
                            radio(choices.keepZone, isSelected: !keepsUTC) { keepsUTC = false }
                            radio(choices.keepUTC, isSelected: keepsUTC) { keepsUTC = true }
                        } header: {
                            Text("When clocks change")
                        } footer: {
                            if let note = AlarmText.dstNote(preview, now: now, device: device) {
                                NoteLine(systemImage: "clock.arrow.circlepath", text: note, inset: 0)
                                    .padding(.top, Spacing.xs)
                            }
                        }
                    }

                    Section {
                        LabeledContent("Repeat", value: AlarmText.repeatText(draft.repeatDays))
                        WeekdayPicker(days: Binding(get: { draft.repeatDays.sorted() },
                                                    set: { draft.repeatDays = Set($0) }),
                                      first: appState.firstWeekday)
                        LabeledContent("Label") {
                            TextField("Alarm", text: $draft.label)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section {
                        // AlarmKit plays the system alarm sound or a bundled file; iOS ringtones
                        // aren't available to apps (decision BH).
                        LabeledContent("Sound", value: "Default")
                        Picker("Snooze", selection: $draft.snoozeMinutes) {
                            Text("Off").tag(Int?.none)
                            ForEach(Self.snoozeChoices, id: \.self) { Text("\($0) min").tag(Int?.some($0)) }
                        }
                    } footer: {
                        Text("Rings at your iPhone's alarm volume, through Silent and Focus.")
                    }

                    if let onDelete {
                        Section {
                            Button(role: .destructive) {
                                onDelete()
                                dismiss()
                            } label: {
                                Label("Delete alarm", systemImage: "trash")
                                    .foregroundStyle(.statusDanger)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            // Menus and Cancel are not "on" states: neutral, not orange (spec §3.2).
            .tint(.textPrimary)
            .navigationTitle(original == nil ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // The sheet's one filled orange button (spec §3.2).
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                        .foregroundStyle(.onAccent)
                }
            }
        }
        .presentationBackground(.bgElevated)
        .sheet(isPresented: $isPickingZone) {
            ZonePickerSheet(title: "Time zone", allowsLocal: true, selected: draft.zoneID) { zone in
                draft.zoneID = zone?.id
            }
        }
        .onAppear {
            // A Keep UTC alarm opens on its zone's time now, so Save keeps its UTC time (BE).
            if let original { draft = original.forEditing(now: appState.now(), device: .device) }
        }
    }

    private var zoneName: String {
        draft.zoneID.flatMap(Zone.init).map(ZoneCatalog.displayName) ?? "Local"
    }

    /// A radio row: an accent dot when chosen (an active state, §3.2), title and detail.
    private func radio(_ choice: PolicyChoice, isSelected: Bool, select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .meridianFont(.headline)
                    .foregroundStyle(isSelected ? Color.accent : .textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .meridianFont(.body)
                        .foregroundStyle(.textPrimary)
                    Text(choice.detail)
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Spacing.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        onSave(draft.saving(keepsUTC: keepsUTC, now: appState.now(), device: .device))
        dismiss()
    }
}
