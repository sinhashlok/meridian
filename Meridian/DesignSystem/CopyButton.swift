import SwiftUI
import UIKit  // UIPasteboard

/// Copies `text`, then confirms with the checkmark glyph swap (spec §3.1) and the success
/// haptic. Unstyled: callers pick the button style (`.pill`, `.bordered`, `.plain`).
struct CopyButton: View {
    let text: String
    var title = "Copy"

    @State private var copies = 0
    @State private var showsCopied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copies += 1
            showsCopied = true
        } label: {
            Label(showsCopied ? "Copied" : title, systemImage: showsCopied ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .sensoryFeedback(Haptic.success, trigger: copies)
        // Restarts on every copy (the previous wait is cancelled), so a second tap keeps
        // "Copied" up for the full 2 seconds.
        .task(id: copies) {
            guard copies > 0, (try? await Task.sleep(for: .seconds(2))) != nil else { return }
            showsCopied = false
        }
    }
}
