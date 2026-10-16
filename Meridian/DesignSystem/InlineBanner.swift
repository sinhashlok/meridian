import SwiftUI

/// A one-line neutral note in the flow of the screen ("No hour works for all 3 cities").
/// Not an error, so no danger colour (spec principle 2: honest, never silent).
struct InlineBanner: View {
    let text: String
    var systemImage = "info.circle"

    var body: some View {
        Label(text, systemImage: systemImage)
            .meridianFont(.body)
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s)
            .background(.bgElevated, in: .rect(cornerRadius: Radius.row, style: .continuous))
    }
}
