import SwiftUI

extension View {
    /// The shared header from spec §2 (UTC pill · inline title · gear) plus the app
    /// background. Apply inside each tab's `NavigationStack`.
    func meridianScreen(title: String) -> some View {
        modifier(ScreenChrome(title: title))
    }
}

private struct ScreenChrome: ViewModifier {
    let title: String
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(.bgBase, for: .navigation)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    UTCPill()
                }
                // The pill draws its own capsule; hide the iOS 26 glass bubble behind it.
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        appState.isSettingsPresented = true
                    }
                }
            }
    }
}
