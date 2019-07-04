/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol OpenProjectLayoutFactoryProtocol: class {
    func createLayout(from content: OpenProjectContent,
                      layoutMetadata: OpenProjectLayoutMetadata) -> OpenProjectLayout
}

extension OpenProjectViewModelFactory: OpenProjectLayoutFactoryProtocol {
    func createLayout(from content: OpenProjectContent,
                      layoutMetadata: OpenProjectLayoutMetadata) -> OpenProjectLayout {
        var layout = OpenProjectLayout {
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

    private func fillText(for layout: inout OpenProjectLayout,
                          from content: OpenProjectContent,
                          layoutMetadata: OpenProjectLayoutMetadata) {
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

    private func fillFundingProgress(for layout: inout OpenProjectLayout,
                                     from content: OpenProjectContent,
                                     layoutMetadata: OpenProjectLayoutMetadata) {
        layout.fundingProgressDetailsSize = content.fundingProgressDetails
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.fundingDetailsFont,
                         options: layoutMetadata.drawingOptions)

        layout.remainedTimeDetailsSize = content.remainedTimeDetails
            .drawingSize(for: layoutMetadata.drawingBoundingSize,
                         font: layoutMetadata.remainedTimeDetailsFont,
                         options: layoutMetadata.drawingOptions)

        layout.itemSize.height += layoutMetadata.fundingDetailsTopSpacing

        let progressDetailsWidth = layout.fundingProgressDetailsSize.width + layout.remainedTimeDetailsSize.width
            + layoutMetadata.minimumHorizontalSpacing

        if progressDetailsWidth <= layoutMetadata.drawingBoundingSize.width {
            layout.itemSize.height += max(layout.fundingProgressDetailsSize.height,
                                          layout.remainedTimeDetailsSize.height)
        } else {
            layout.itemSize.height += layout.fundingProgressDetailsSize.height + layoutMetadata.multilineSpacing
                + layout.remainedTimeDetailsSize.height
        }

        layout.itemSize.height += layoutMetadata.progressTopSpacing + layoutMetadata.progressBarHeight
    }

    private func fillActions(for layout: inout OpenProjectLayout,
                             from content: OpenProjectContent,
                             layoutMetadata: OpenProjectLayoutMetadata) {
        let boundingSize = CGSize(width: layoutMetadata.drawingBoundingSize.width,
                                  height: layoutMetadata.actionsHeight)

        layout.voteTitleSize = content.voteTitle
            .drawingSize(for: boundingSize,
                         font: layoutMetadata.votingStateFont,
                         options: layoutMetadata.drawingOptions)

        if let votedFriendsDetails = content.votedFriendsDetails {
            layout.votedFriendsDetailsSize = votedFriendsDetails
                .drawingSize(for: boundingSize,
                             font: layoutMetadata.votedFriendsFont,
                             options: layoutMetadata.drawingOptions)
        }

        if let favoriteDetails = content.favoriteDetails {
            layout.favoriteDetailsSize = favoriteDetails
                .drawingSize(for: boundingSize,
                             font: layoutMetadata.favoriteFont,
                             options: layoutMetadata.drawingOptions)
        }

        layout.itemSize.height += layoutMetadata.actionsTopSpacing

        let votingStateWidth = layoutMetadata.votingIconWidth + layoutMetadata.votingIconHorizontalSpacing
            + layout.voteTitleSize.width
        let votedFriendsWidth = layout.votedFriendsDetailsSize.width
        let favoriteWidth = layout.favoriteDetailsSize.width + layoutMetadata.favoriteHorizontalSpacing
            + layoutMetadata.favoriteIconSize.width

        if votingStateWidth + layoutMetadata.votedFriendsHorizontalSpacing
            + votedFriendsWidth + layoutMetadata.minimumHorizontalSpacing
            + favoriteWidth <= layoutMetadata.drawingBoundingSize.width {
            layout.itemSize.height += layoutMetadata.actionsHeight
        } else if votingStateWidth + layoutMetadata.votedFriendsHorizontalSpacing
            + votedFriendsWidth <= layoutMetadata.drawingBoundingSize.width {
            layout.itemSize.height += 2 * layoutMetadata.actionsHeight + layoutMetadata.multilineSpacing
        } else if votedFriendsWidth + layoutMetadata.minimumHorizontalSpacing
            + favoriteWidth <= layoutMetadata.drawingBoundingSize.width {
            layout.itemSize.height += 2 * layoutMetadata.actionsHeight + layoutMetadata.multilineSpacing
        } else {
            layout.itemSize.height += 3 * layoutMetadata.actionsHeight + 2 * layoutMetadata.multilineSpacing
        }
    }

    private func fillReward(for layout: inout OpenProjectLayout,
                            from content: OpenProjectContent,
                            layoutMetadata: OpenProjectLayoutMetadata) {
        if let rewardDetails = content.rewardDetails {

            var boundingSize = layoutMetadata.drawingBoundingSize

            if layoutMetadata.rewardIconSize != .zero {
                boundingSize.width -= layoutMetadata.rewardIconSize.width + layoutMetadata.rewardHorizontalSpacing
            }

            layout.rewardDetailsSize = rewardDetails
                .drawingSize(for: boundingSize,
                             font: layoutMetadata.rewardFont,
                             options: layoutMetadata.drawingOptions)

            layout.itemSize.height += layoutMetadata.separatorTopSpacing + layoutMetadata.separatorWidth
            layout.itemSize.height += layoutMetadata.rewardTopSpacing
            layout.itemSize.height += layout.rewardDetailsSize.height
        }
    }

    private func finalizeItemSize(for layout: inout OpenProjectLayout, from content: OpenProjectContent,
                                  layoutMetadata: OpenProjectLayoutMetadata) {
        layout.imageSize = CGSize(width: layout.itemSize.width,
                                  height: layoutMetadata.minimumImageHeight)

        if layout.itemSize.height < layoutMetadata.minimumItemHeight {
            layout.imageSize.height += layoutMetadata.minimumItemHeight - layout.itemSize.height
            layout.itemSize.height = layoutMetadata.minimumItemHeight
        }
    }
}
