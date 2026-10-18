import SwiftUI

/// Children side by side at their natural widths, the last one pushed to the trailing
/// edge (like a `Spacer` before it); stacked on the leading edge when the row doesn't fit
/// (large text). Use it instead of `ViewThatFits` with an HStack and a VStack of the same
/// views: ViewThatFits swaps in a second copy of the views, so the accessibility audit
/// loses track of the text as it grows and reports it as not scaling.
struct RowOrStack: Layout {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = Spacing.s
    var stackSpacing: CGFloat = Spacing.xs
    /// Stacked, show the last child first (ActionHeader puts its button above the summary).
    var stacksLastFirst = false
    /// In a row, push the last child to the trailing edge; false keeps it next to the others.
    var pushesLast = true

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = Self.finite(proposal.width)
        if let row = row(subviews, fitting: width) {
            return CGSize(width: width ?? row.width, height: row.height)
        }
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        let height = sizes.map(\.height).reduce(0, +) + stackSpacing * CGFloat(max(sizes.count - 1, 0))
        return CGSize(width: width ?? sizes.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if let row = row(subviews, fitting: bounds.width) {
            var x = bounds.minX
            for (index, subview) in subviews.enumerated() {
                let size = row.sizes[index]
                if pushesLast, index == subviews.count - 1, index > 0 { x = bounds.maxX - size.width }
                subview.place(at: CGPoint(x: x, y: bounds.minY + row.tops[index]), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            return
        }
        let order = stacksLastFirst ? Array(subviews.indices.reversed()) : Array(subviews.indices)
        let proposal = ProposedViewSize(width: bounds.width, height: nil)
        var y = bounds.minY
        for index in order {
            let height = subviews[index].sizeThatFits(proposal).height
            subviews[index].place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + stackSpacing
        }
    }

    private struct Row {
        var sizes: [CGSize]
        var tops: [CGFloat]
        var width: CGFloat
        var height: CGFloat
    }

    /// The row at natural widths, or nil when it's wider than `width`.
    private func row(_ subviews: Subviews, fitting width: CGFloat?) -> Row? {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
        if let width, rowWidth > width { return nil }
        // Line the children up on `alignment` (e.g. first baselines), measured from the top.
        let guides = subviews.indices.map { subviews[$0].dimensions(in: ProposedViewSize(sizes[$0]))[alignment] }
        let line = guides.max() ?? 0
        let tops = guides.map { line - $0 }
        let height = zip(tops, sizes).map { $0 + $1.height }.max() ?? 0
        return Row(sizes: sizes, tops: tops, width: rowWidth, height: height)
    }

    private static func finite(_ value: CGFloat?) -> CGFloat? {
        value.flatMap { $0.isFinite ? $0 : nil }
    }
}
