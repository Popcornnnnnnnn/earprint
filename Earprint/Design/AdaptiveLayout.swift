import SwiftUI

/// Size and fold facts for one container, read from its `GeometryProxy`.
///
/// iPhone Duo (iOS 27.1+) reports its hinge as a *division* reserved region. It is active only while the
/// device is partially folded; while flat it is inactive but still present, which tells us the display can fold.
/// Frames are in the measured view's own coordinates and already include the system's margins.
struct LayoutSpace: Equatable {
    var size: CGSize = .zero
    /// Active fold running top to bottom (book pose): content should sit left and right of it.
    var verticalFold: CGRect?
    /// Active fold running left to right (laptop pose): content should sit above and below it.
    var horizontalFold: CGRect?
    /// The display has a hinge here, even if it is flat right now.
    var canFold = false

    init() {}

    init(_ proxy: GeometryProxy) {
        size = proxy.size
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
            canFold = !regions.isEmpty
            for region in regions where region.isActive {
                if region.frame.height >= region.frame.width {
                    verticalFold = verticalFold ?? region.frame
                } else {
                    horizontalFold = horizontalFold ?? region.frame
                }
            }
        }
    }

    /// Room for an extra level of content (two columns, front and back side by side).
    var isWide: Bool { size.width >= 600 }
    var isLandscape: Bool { size.width > size.height }
}

extension View {
    /// Keeps `space` in sync with this view's size and the fold.
    func readLayoutSpace(_ space: Binding<LayoutSpace>) -> some View {
        onGeometryChange(for: LayoutSpace.self) { LayoutSpace($0) } action: { space.wrappedValue = $0 }
    }
}

/// Widths for a two-column layout. With an active vertical fold, each column stays on its own side of the hinge.
struct ColumnSplit: Equatable {
    var leading: CGFloat
    var trailing: CGFloat
    var gap: CGFloat
    var padding: CGFloat

    init(space: LayoutSpace, padding: CGFloat, gap: CGFloat) {
        let width = space.size.width
        self.padding = padding
        if let fold = space.verticalFold, fold.minX > padding, fold.maxX < width - padding {
            // The fold frame already includes the system margins.
            leading = fold.minX - padding
            trailing = width - padding - fold.maxX
            self.gap = fold.width
        } else {
            let column = max(0, (width - padding * 2 - gap) / 2)
            leading = column
            trailing = column
            self.gap = gap
        }
    }
}

/// Grid columns that follow the available width.
/// - Compact widths keep the familiar two columns.
/// - On a display that can fold the count stays even, so the hinge falls between cards (HIG: iPhone Duo).
/// - With an active vertical fold the middle gutter widens to cover the hinge.
struct AdaptiveGrid {
    var columns: [GridItem]
    var leadingPadding: CGFloat
    var trailingPadding: CGFloat

    init(space: LayoutSpace, padding: CGFloat, spacing: CGFloat, minItemWidth: CGFloat, maxColumns: Int = 6) {
        let usable = max(0, space.size.width - padding * 2)
        var count = Int((usable + spacing) / (minItemWidth + spacing))
        if space.canFold || space.verticalFold != nil { count -= count % 2 }
        count = min(max(count, 2), maxColumns)

        if let fold = space.verticalFold, count.isMultiple(of: 2),
           fold.minX > padding, fold.maxX < space.size.width - padding {
            // The fold frame already includes the system margins, so cards may sit right next to it.
            let half = count / 2
            let side = CGFloat(half)
            let leftRoom = fold.minX - padding
            let rightRoom = space.size.width - padding - fold.maxX
            let item = max(1, (min(leftRoom, rightRoom) - spacing * (side - 1)) / side)
            let block = item * side + spacing * (side - 1)
            // Center each half of the grid on its own side of the fold.
            let leftSlack = max(0, leftRoom - block) / 2
            let rightSlack = max(0, rightRoom - block) / 2
            let middle = leftSlack + fold.width + rightSlack
            columns = (0..<count).map { index in
                GridItem(.fixed(item), spacing: index == half - 1 ? middle : spacing)
            }
            leadingPadding = padding + leftSlack
            trailingPadding = padding + rightSlack
        } else {
            columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
            leadingPadding = padding
            trailingPadding = padding
        }
    }
}

/// Shows a view designed at a fixed size, scaled to fit the space it is offered.
/// Layout uses the scaled size, so neighbours and safe areas see the real footprint.
struct FittedDesign<Content: View>: View {
    let designSize: CGSize
    var maxScale: CGFloat = 1
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let scale = min(maxScale, geo.size.width / designSize.width, geo.size.height / designSize.height)
            content
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(max(scale, 0.01))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
