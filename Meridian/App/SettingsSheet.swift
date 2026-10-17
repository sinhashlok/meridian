import SwiftUI
import UIKit  // only for UIApplication.openSettingsURLString

/// Settings sheet stub (spec §2). Rows show their defaults; wiring lands in M8.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    LabeledContent("24-hour time", value: "Follow system")
                    LabeledContent("Week start", value: "Follow locale")
                }
                .listRowBackground(Color.bgSurface)

                Section("Zones") {
                    LabeledContent("Default working hours", value: "09:00–18:00")
                    LabeledContent("Default work days", value: "Mon–Fri")
                    Toggle("Warn before clocks change", isOn: .constant(false))
                        .disabled(true)
                }
                .listRowBackground(Color.bgSurface)

                Section("Dates") {
                    LabeledContent("Default fiscal profile", value: "None")
                }
                .listRowBackground(Color.bgSurface)

                Section("Permissions") {
                    LabeledContent("Alarms", value: "Not requested")
                    LabeledContent("Notifications", value: "Not requested")
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                .listRowBackground(Color.bgSurface)

                #if DEBUG
                AlarmKitProbeSection()
                    .listRowBackground(Color.bgSurface)
                #endif

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }
                .listRowBackground(Color.bgSurface)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationBackground(.bgElevated)
    }
}

#Preview {
    Text("Presenting view")
        .sheet(isPresented: .constant(true)) { SettingsSheet() }
        .preferredColorScheme(.dark)
}
