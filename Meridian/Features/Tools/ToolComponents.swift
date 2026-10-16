import MeridianCore
import SwiftData
import SwiftUI
import UIKit  // UIPasteboard

/// The rounded input box every tool starts with: a large mono field, a clear button and
/// optional trailing content (Dates' kind label and Today). Outlined in `statusDanger`
/// when the input has a problem.
struct ToolInputBox<Trailing: View>: View {
    let placeholder: String
    @Binding var text: String
    var isInvalid = false
    var keyboard: UIKeyboardType = .numbersAndPunctuation
    /// Dates hides it: its Today button already resets the input.
    var showsClear = true
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the trailing controls move under the field.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.s))
        layout {
            HStack(spacing: Spacing.s) {
                // Wraps long epochs; a single-line field (Dates) scrolls instead.
                TextField(placeholder, text: $text, axis: showsClear ? .vertical : .horizontal)
                    .meridianFont(.monoTime)
                    .foregroundStyle(.textPrimary)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if showsClear, !text.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.textTertiary)
                        .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
                }
            }
            HStack(spacing: Spacing.s) { trailing() }
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 64)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(isInvalid ? Color.statusDanger : Color.separatorLine, lineWidth: isInvalid ? 1.5 : 1)
        }
    }
}

extension ToolInputBox where Trailing == EmptyView {
    init(placeholder: String, text: Binding<String>, isInvalid: Bool = false,
         keyboard: UIKeyboardType = .numbersAndPunctuation) {
        self.init(placeholder: placeholder, text: text, isInvalid: isInvalid, keyboard: keyboard) { EmptyView() }
    }
}

/// A card of rows separated by hairlines (`bgSurface`, 16pt corners).
struct ToolCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                    if index > 0 {
                        Rectangle().fill(Color.separatorLine).frame(height: 1).padding(.leading, Spacing.m)
                    }
                    subview
                }
            }
        }
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }
}

/// A labelled value with a 44pt copy button (spec §4.6). On copy the glyph swaps to a
/// checkmark, the label says "Copied" and the row lifts to `bgElevated` (spec §3.1:
/// success = checkmark glyph swap).
struct CopyRow: View {
    let label: String
    let value: String
    let copyText: String
    /// Label beside the value (Dates) instead of above it (Epoch).
    var inline = false

    @State private var copies = 0
    @State private var showsCopied = false

    var body: some View {
        HStack(spacing: Spacing.s) {
            if inline {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        labelText
                        Spacer(minLength: Spacing.s)
                        valueText.multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 2) { labelText; valueText }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) { labelText; valueText }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                UIPasteboard.general.string = copyText
                copies += 1
                showsCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showsCopied = false
                }
            } label: {
                Image(systemName: showsCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(.textPrimary)
                    .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsCopied ? "Copied" : "Copy \(label)")
        }
        .padding(.leading, Spacing.m)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: Spacing.minRowHeight)
        .background(showsCopied ? Color.bgElevated : .clear)
        .animation(Motion.stateChange, value: showsCopied)
        .sensoryFeedback(Haptic.success, trigger: copies)
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(showsCopied && !inline ? "\(label) · Copied" : label)
            .meridianFont(inline ? .body : .sub)
            .foregroundStyle(.textSecondary)
    }

    private var valueText: some View {
        Text(value)
            .meridianFont(.monoBody)
            .foregroundStyle(.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

/// A blocking input problem: danger triangle (spec §3.1: danger always with a symbol),
/// title, detail and optional fix and Clear buttons.
struct ProblemBlock: View {
    let title: String
    let detail: String
    var fixLabel: Text?
    var onFix: (() -> Void)?
    var onClear: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: "exclamationmark.triangle")
                .meridianFont(.headline)
                .foregroundStyle(.statusDanger)
                .accessibilityLabel("Problem")
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
                Text(detail)
                    .meridianFont(.body)
                    .foregroundStyle(.textSecondary)
                if onFix != nil || onClear != nil {
                    HStack(spacing: Spacing.s) {
                        if let fixLabel, let onFix {
                            Button(action: onFix) {
                                fixLabel
                                    .meridianFont(.headline)
                                    .foregroundStyle(.textPrimary)
                                    .padding(.horizontal, Spacing.m)
                                    .frame(minHeight: Spacing.minTapTarget)
                                    .background(.bgElevated, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                        if let onClear {
                            Button("Clear", action: onClear)
                                .meridianFont(.body)
                                .foregroundStyle(.textSecondary)
                                .frame(minHeight: Spacing.minTapTarget)
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dashed box saying what appears once the input is valid.
struct PlaceholderBox: View {
    let text: String

    var body: some View {
        Text(text)
            .meridianFont(.body)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.separatorLine, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
    }
}

/// An info line: symbol, optional bold lead, then the text in `textSecondary`.
struct NoteLine: View {
    var systemImage = "info.circle"
    var lead: String?
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: systemImage)
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            if let lead {
                Text("\(Text(lead).bold().foregroundStyle(.textPrimary)) \(text)")
                    .foregroundStyle(.textSecondary)
            } else {
                Text(text).foregroundStyle(.textSecondary)
            }
        }
        .meridianFont(.body)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.xs)
    }
}

/// Section caption above a card: `In your zones`, `Next 5 runs`.
struct ToolCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
            .padding(.top, Spacing.xs)
    }
}

/// Interpret as / Evaluate in (decision X): UTC, the phone's zone and saved zones.
struct ToolZoneMenu: View {
    let prefix: String
    @Binding var zoneID: String
    let zones: [SavedZone]

    var body: some View {
        let device = Zone.device
        Menu {
            Picker(prefix.isEmpty ? "Zone" : prefix, selection: $zoneID) {
                Text("UTC").tag(Zone.utc.id)
                if device != .utc {
                    Text("This phone · \(ZoneCatalog.displayName(for: device))").tag(device.id)
                }
                ForEach(zones.filter { $0.ianaID != device.id && $0.ianaID != Zone.utc.id }) { saved in
                    Text(saved.name).tag(saved.ianaID)
                }
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text(prefix.isEmpty ? Self.name(for: zoneID, zones: zones) : "\(prefix) \(Self.name(for: zoneID, zones: zones))")
                Image(systemName: "chevron.down").imageScale(.small)
            }
            .meridianFont(.headline)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: Spacing.minTapTarget)
            .background(.bgElevated, in: .capsule)
        }
    }

    /// `UTC`, a saved zone's name, or the catalogue name.
    static func name(for zoneID: String, zones: [SavedZone]) -> String {
        guard let zone = Zone(zoneID), zone != .utc else { return "UTC" }
        return zones.first { $0.ianaID == zoneID }?.name ?? ZoneCatalog.displayName(for: zone)
    }
}
