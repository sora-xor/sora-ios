/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol FinishedProjectLayoutFactoryProtocol: class {
    func createLayout(from content: FinishedProjectContent,
                      layoutMetadata: FinishedProjectLayoutMetadata) -> FinishedProjectLayout
}

extension FinishedProjectViewModelFactory: FinishedProjectLayoutFactoryProtocol {
    func createLayout(from content: FinishedProjectContent,
                      layoutMetadata: FinishedProjectLayoutMetadata) -> FinishedProjectLayout {
        var layout = FinishedProjectLayout {
            $0.itemSize = CGSize(width: layoutMetadata.itemWidth,
                                 height: layoutMetadata.minimumImageHeight + layoutMetadata.contentInsets.bottom)
        }

        fillText(for: &layout,
                 from: content,
                 layoutMetadata: layoutMetadata)

        fillFundingProgress(for: &layout,
                            from: content,
                            layoutMetadata: layoutMetadata)

        fillActions(for: &layout,
                    from: content,
                    layoutMetadata: layoutMetadata)

        fillReward(for: &layout,
                   from: content,
                   layoutMetadata: layoutMetadata)

        finalizeItemSize(for: &layout,
                         from: content,
                         layoutMetadata: layoutMetadata)

        return layout
    }

    private func fillText(for layout: inout FinishedProjectLayout,
                          from content: FinishedProjectContent,
                          layoutMetadata: FinishedProjectLayoutMetadata) {
        layout.titleSize = content.title
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.titleFont,
                         options: layoutMetadata.drawingOptions)

        layout.itemSize.height += layout.titleSize.height + layoutMetadata.contentInsets.top

        layout.detailsSize = content.details
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.detailsFont,
                         options: layoutMetadata.drawingOptions)

        layout.itemSize.height += layout.detailsSize.height + layoutMetadata.detailsTopSpacing
    }

    private func fillFundingProgress(for layout: inout FinishedProjectLayout,
                                     from content: FinishedProjectContent,
                                     layoutMetadata: FinishedProjectLayoutMetadata) {
        layout.fundingProgressDetailsSize = content.fundingProgressDetails
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.fundingProgressDetailsFont,
                         options: layoutMetadata.drawingOptions)

        layout.completionTimeDetailsSize = content.completionTimeDetails
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.completionDetailsFont,
                         options: layoutMetadata.drawingOptions)

        let width = layout.fundingProgressDetailsSize.width + layoutMetadata.minimumHorizontalSpacing
            + layout.completionTimeDetailsSize.width

        layout.itemSize.height += layoutMetadata.fundingProgressDetailsTopSpacing

        if width <= layoutMetadata.drawingBoundingSize.width {
            layout.itemSize.height += max(layout.fundingProgressDetailsSize.height,
                                          layout.completionTimeDetailsSize.height)
        } else {
            layout.itemSize.height += layout.fundingProgressDetailsSize.height
            layout.itemSize.height += layoutMetadata.multilineSpacing
            layout.itemSize.height += layout.completionTimeDetailsSize.height
        }
    }

    private func fillActions(for layout: inout FinishedProjectLayout,
                             from content: FinishedProjectContent,
                             layoutMetadata: FinishedProjectLayoutMetadata) {
        layout.itemSize.height += layoutMetadata.separatorTopSpacing + layoutMetadata.separatorWidth

        layout.itemSize.height += layoutMetadata.votingTitleTopSpacing

        let boundingSize = CGSize(width: layoutMetadata.drawingBoundingSize.width,
                                  height: layoutMetadata.actionsHeight)

        if let favoriteDetails = content.favoriteDetails {
            layout.favoriteDetailsSize = favoriteDetails.drawingSize(for: boundingSize,
                                                                     font: layoutMetadata.favoriteFont,
                                                                     options: layoutMetadata.drawingOptions)
        }

        layout.votingTitleSize = content.votingTitle.drawingSize(for: boundingSize,
                                                                 font: layoutMetadata.votingTitleFont,
                                                                 options: layoutMetadata.drawingOptions)

        var width = layoutMetadata.votingIconWidth + layoutMetadata.votingIconHorizontalSpacing
            + layout.votingTitleSize.width
        width += layoutMetadata.minimumHorizontalSpacing
        width += layout.favoriteDetailsSize.width + layoutMetadata.favoriteDetailsHorizontalSpacing
            + layoutMetadata.favoriteIconWidth

        if width <= layoutMetadata.drawingBoundingSize.width {
            layout.itemSize.height += layoutMetadata.actionsHeight
        } else {
            layout.itemSize.height += 2 * layoutMetadata.actionsHeight + layoutMetadata.multilineSpacing
        }
    }

    private func fillReward(for layout: inout FinishedProjectLayout,
                            from content: FinishedProjectContent,
                            layoutMetadata: FinishedProjectLayoutMetadata) {
        if let rewardDetails = content.rewardDetails {
            var boundingSize = layoutMetadata.drawingBoundingSize

            if layoutMetadata.rewardIconSize != .zero {
                boundingSize.width -= layoutMetadata.rewardIconSize.width + layoutMetadata.rewardHorizontalSpacing
            }

            layout.rewardDetailsSize = rewardDetails.drawingSize(for: boundingSize,
                                                                 font: layoutMetadata.rewardFont,
                                                                 options: layoutMetadata.drawingOptions)

            layout.itemSize.height += layoutMetadata.rewardDetailsTopSpacing + layout.rewardDetailsSize.height
        }
    }

    private func finalizeItemSize(for layout: inout FinishedProjectLayout,
                                  from content: FinishedProjectContent,
                                  layoutMetadata: FinishedProjectLayoutMetadata) {
        layout.imageSize = CGSize(width: layout.itemSize.width,
                                  height: layoutMetadata.minimumImageHeight)

        if layout.itemSize.height < layoutMetadata.minimumItemHeight {
            layout.imageSize.height += layoutMetadata.minimumItemHeight - layout.itemSize.height
            layout.itemSize.height = layoutMetadata.minimumItemHeight
        }
    }
}
