import UIKit

protocol ReferendumLayoutFactoryProtocol: class {
    func createLayout(from content: ReferendumContent,
                      layoutMetadata: ReferendumLayoutMetadata) -> ReferendumLayout
}

extension ReferendumViewModelFactory: ReferendumLayoutFactoryProtocol {
    func createLayout(from content: ReferendumContent,
                      layoutMetadata: ReferendumLayoutMetadata) -> ReferendumLayout {
        var layout = ReferendumLayout {
            $0.itemSize = CGSize(width: layoutMetadata.itemWidth,
                                 height: layoutMetadata.minimumImageHeight + layoutMetadata.contentInsets.bottom)
        }

        layout.itemSize.height += layoutMetadata.contentInsets.top + layoutMetadata.remainedHeight

        fillText(for: &layout, from: content, layoutMetadata: layoutMetadata)

        layout.itemSize.height += layoutMetadata.bottomBarTopSpacing + layoutMetadata.bottomSeparatorHeight +
            layoutMetadata.votingTitleTopSpacing + layoutMetadata.votingTitleHeight
        layout.itemSize.height += layoutMetadata.progressBarTopSpacing + layoutMetadata.progressBarHeight +
            layoutMetadata.votingDetailsTopSpacing + layoutMetadata.votingIndicatorSize.height

        finalizeItemSize(for: &layout,
                         from: content,
                         layoutMetadata: layoutMetadata)

        return layout
    }

    private func fillText(for layout: inout ReferendumLayout,
                          from content: ReferendumContent,
                          layoutMetadata: ReferendumLayoutMetadata) {
        layout.titleSize = content.title
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.titleFont,
                         options: layoutMetadata.drawingOptions)

        layout.itemSize.height += layout.titleSize.height + layoutMetadata.titleTopSpacing

        layout.detailsSize = content.details
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.detailsFont,
                         options: layoutMetadata.drawingOptions)

        layout.itemSize.height += layout.detailsSize.height + layoutMetadata.detailsTopSpacing
    }

    private func finalizeItemSize(for layout: inout ReferendumLayout,
                                  from content: ReferendumContent,
                                  layoutMetadata: ReferendumLayoutMetadata) {
        layout.imageSize = CGSize(width: layout.itemSize.width,
                                  height: layoutMetadata.minimumImageHeight)

        if layout.itemSize.height < layoutMetadata.minimumItemHeight {
            layout.imageSize.height += layoutMetadata.minimumItemHeight - layout.itemSize.height
            layout.itemSize.height = layoutMetadata.minimumItemHeight
        }
    }
}
