import MeridianCore
import SwiftData
import SwiftUI
import UIKit  // only for UIApplication.openSettingsURLString

/// Settings (spec §2, board Settings). Always 24-hour, so there is no 24-hour row
/// (decision BQ). Every change is saved at once through `AppState`.
struct SettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedFiscalProfile.order) private var fiscalRows: [SavedFiscalProfile]

    /// `nil` until read, so a row never shows a status it hasn't checked.
    @State private var alarms: AlarmService.Permission?
    @State private var notifications: AlarmService.Permission?

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section {
                    Picker("Week start", selection: $appState.weekStart) {
                        ForEach(WeekStart.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Time")
                } footer: {
                    Text("Used by the Planner and weekly schedules. ISO weeks always start Monday; fiscal profiles set their own.")
                }
                .listRowBackground(Color.bgSurface)

                Section {
                    NavigationLink {
                        DefaultHoursPage()
                    } label: {
                        LabeledContent("Default working hours") {
                            Text(ClockTime.rangeText(appState.defaultWorkStart, appState.defaultWorkEnd))
                                .meridianFont(.monoBody)
                        }
                    }
                    NavigationLink {
                        DefaultDaysPage()
                    } label: {
                        LabeledContent("Default work days",
                                       value: Weekdays.summary(Set(appState.defaultWorkDays), from: appState.firstWeekday))
                    }
                } header: {
                    Text("Work")
                } footer: {
                    Text("New zones start with these. Each zone can have its own in Zones.")
                }
                .listRowBackground(Color.bgSurface)

                fiscalSection
                    .listRowBackground(Color.bgSurface)

                Section {
                    Toggle("Warn before clocks change", isOn: $appState.warnsBeforeClockChanges)
                } header: {
                    Text("Clock changes")
                } footer: {
                    Text("A banner in Zones 14 days before a change. In-app only; no notifications.")
                }
                .listRowBackground(Color.bgSurface)

                Section {
                    permissionRow("Alarms", alarms) {
                        _ = await AlarmService.alarmsDenied(askingIf: true)
                    }
                    permissionRow("Notifications", notifications) {
                        _ = await AlarmService.notificationsDenied(askingIf: true)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        LabeledContent("Open iOS Settings") { Image(systemName: "chevron.right") }
                    }
                    .foregroundStyle(.textPrimary)
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Job reminders need notifications.")
                }
                .listRowBackground(Color.bgSurface)

                #if DEBUG
                AlarmKitProbeSection()
                    .listRowBackground(Color.bgSurface)
                #endif

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Time zone data") {
                        Text(ZoneClock.dataVersion).meridianFont(.monoBody)
                    }
                }
                .listRowBackground(Color.bgSurface)
            }
            .scrollContentBackground(.hidden)
            .defaultScrollAnchor(DebugLaunch.startsAtBottom ? .bottom : .top)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationBackground(.bgElevated)
        .task(id: scenePhase) {
            if scenePhase != .background { await readPermissions() }
        }
    }

    /// The active fiscal profile is the default (decision CA); Tools › Dates shares it.
    @ViewBuilder private var fiscalSection: some View {
        let list = FiscalStore.list(from: fiscalRows)
        Section {
            if list.profiles.isEmpty {
                LabeledContent("Default fiscal profile", value: "None")
            } else {
                Picker("Default fiscal profile", selection: Binding(
                    get: { list.activeIndex ?? 0 },
                    set: { index in FiscalStore.update(fiscalRows, in: context) { $0.activate(at: index) } })) {
                    ForEach(list.profiles.indices, id: \.self) { Text(list.profiles[$0].name).tag($0) }
                }
                .pickerStyle(.navigationLink)
            }
        } header: {
            Text("Dates")
        } footer: {
            if list.profiles.isEmpty { Text("Add a fiscal calendar in Tools › Dates.") }
        }
    }

    /// `✓ Allowed`, `Off`, or an Allow button while not yet asked (decision CB).
    private func permissionRow(_ title: String, _ permission: AlarmService.Permission?,
                               ask: @escaping () async -> Void) -> some View {
        LabeledContent(title) {
            switch permission {
            case .allowed:
                Label("Allowed", systemImage: "checkmark").labelStyle(.titleAndIcon)
            case .off:
                Text("Off")
            case nil:
                EmptyView()
            case .notAsked:
                Button("Allow") {
                    Task {
                        await ask()
                        await readPermissions()
                    }
                }
                .foregroundStyle(.accentText)
            }
        }
    }

    private func readPermissions() async {
        alarms = AlarmService.alarmsPermission
        notifications = DebugLaunch.notificationsOff ? .off : await AlarmService.notificationsPermission()
    }
}

/// Settings › Default working hours: what new zones start with (decision BZ).
private struct DefaultHoursPage: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section {
                ClockTimePicker(title: "Starts", time: $appState.defaultWorkStart)
                ClockTimePicker(title: "Ends", time: $appState.defaultWorkEnd)
            } footer: {
                if appState.defaultWorkStart < appState.defaultWorkEnd {
                    Text("Stretch hours are the 2 hours before and 4 hours after.")
                } else {
                    Label("Work hours must end after they start, on the same day. New zones use 09:00–18:00 until then.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.statusDanger)
                }
            }
            .listRowBackground(Color.bgSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgElevated)
        .navigationTitle("Default working hours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Settings › Default work days: a checkmark list in week-start order, like iOS Clock's Repeat.
private struct DefaultDaysPage: View {
    @Environment(AppState.self) private var appState

    private static let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        Form {
            Section {
                ForEach(Weekdays.ordered(from: appState.firstWeekday), id: \.self) { day in
                    let isOn = appState.defaultWorkDays.contains(day)
                    Button {
                        appState.defaultWorkDays = isOn ? appState.defaultWorkDays.filter { $0 != day }
                                                        : (appState.defaultWorkDays + [day]).sorted()
                    } label: {
                        LabeledContent(Self.names[day - 1]) {
                            if isOn { Image(systemName: "checkmark").foregroundStyle(.accentText) }
                        }
                    }
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .listRowBackground(Color.bgSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgElevated)
        .navigationTitle("Default work days")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    Text("Presenting view")
        .sheet(isPresented: .constant(true)) { SettingsSheet() }
        .environment(AppState())
        .modelContainer(AppModel.preview)
        .preferredColorScheme(.dark)
}
