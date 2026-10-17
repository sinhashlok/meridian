import SwiftUI
import UIKit  // UIApplication.openSettingsURLString

/// Decision AI: says plainly when something can't ring through Silent, with a way to fix
/// it. `subject` names what is affected: "timers", "phase changes".
struct AlarmPermissionNote: View {
    let subject: String
    let notificationsDenied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            NoteLine(systemImage: "bell.slash", text: notificationsDenied
                ? "Alarms and notifications are off for Meridian, so \(subject) won't alert."
                : "Alarms are off for Meridian, so \(subject) only notify and stay quiet in Silent mode.")
            Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                .meridianFont(.headline)
                .foregroundStyle(.accentText)
                .frame(minHeight: Spacing.minTapTarget)
                .padding(.leading, Spacing.xxl)
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bgElevated, in: .rect(cornerRadius: Radius.row, style: .continuous))
    }
}
