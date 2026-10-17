import SwiftData
import SwiftUI

/// Sessions has no segments (spec §2).
struct SessionsTab: View {
    var body: some View {
        NavigationStack {
            SessionsView()
                .meridianScreen(title: "Sessions")
        }
    }
}

#Preview {
    SessionsTab()
        .environment(AppState())
        .modelContainer(AppModel.preview)
        .preferredColorScheme(.dark)
}
