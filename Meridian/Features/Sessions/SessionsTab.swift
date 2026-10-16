import SwiftUI

/// Sessions has no segments (spec §2).
struct SessionsTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Sessions",
                systemImage: "scope",
                description: Text("Coming in M6")
            )
            .meridianScreen(title: "Sessions")
        }
    }
}

#Preview {
    SessionsTab()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
