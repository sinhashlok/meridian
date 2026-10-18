import MeridianCore
import SwiftUI

/// One alarm (board AlarmsList): time.row and zone tag, `18:30 IST on this phone` with a
/// DST badge, then `Label · Weekdays`; the switch on the right. Off alarms are dimmed.
/// At accessibility sizes the switch moves under the text.
struct AlarmRow: View {
    let text: AlarmRowText
    let isOn: Bool
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onBadge: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.s))
        layout {
            info
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture(perform: onEdit)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Edits the alarm")
                .accessibilityAction(named: "Edit", onEdit)
            Toggle(isOn: Binding(get: { isOn }, set: onToggle)) {
                Text("\(text.time) \(text.zoneTag ?? "")")
            }
            .labelsHidden()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: Spacing.minRowHeight)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            RowOrStack(alignment: .firstTextBaseline, spacing: Spacing.xs, stackSpacing: 0, pushesLast: false) { time; tag }
            if let phoneLine = text.phoneLine {
                FlowLayout(spacing: Spacing.xs) {
                    phone(phoneLine)
                    badge
                }
            }
            Text(text.caption)
                .meridianFont(.sub)
                .foregroundStyle(isOn ? Color.textSecondary : .textTertiary)
            if text.phoneLine == nil { badge }
        }
    }

    private var time: some View {
        Text(text.time)
            .meridianFont(.timeRow)
            .foregroundStyle(isOn ? Color.textPrimary : .textSecondary)
    }

    @ViewBuilder
    private var tag: some View {
        if let zoneTag = text.zoneTag {
            Text(zoneTag)
                .meridianFont(.headline)
                .foregroundStyle(.textSecondary)
        }
    }

    /// `18:30 IST` in mono, then `on this phone`.
    private func phone(_ line: String) -> some View {
        let suffix = " on this phone"
        let head = line.hasSuffix(suffix) ? String(line.dropLast(suffix.count)) : line
        return Text("\(Text(head).monospaced().foregroundStyle(.textPrimary))\(line.hasSuffix(suffix) ? suffix : "")")
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)
    }

    @ViewBuilder
    private var badge: some View {
        if let dstBadge = text.dstBadge {
            DSTBadge(text: dstBadge, action: onBadge)
        }
    }
}
