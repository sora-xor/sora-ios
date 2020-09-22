/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension ActivityFeedViewModelFactory {
    func createLayout(for content: ActivityFeedItemContent,
                      metadata: ActivityFeedItemLayoutMetadata) -> ActivityFeedItemLayout {
        var layout = ActivityFeedItemLayout()

        var height = metadata.contentInsets.top + metadata.contentInsets.bottom

        includeHeaderLayoutInto(&layout, for: content, metadata: metadata)

        height += layout.itemHeaderHeight

        if let title = content.title {
            includeTitleLayoutInto(&layout, title: title, metadata: metadata)

            height += metadata.titleTopSpacing + layout.titleSize.height
        }

        if let details = content.details {
            includeDetailsLayoutInto(&layout, details: details, metadata: metadata)

            if layout.titleSize.height > 0.0 {
                height += metadata.detailsTopSpacing + layout.detailsSize.height
            } else {
                height += metadata.titleTopSpacing + layout.detailsSize.height
            }
        }

        return layout.with {
            $0.itemSize = CGSize(width: metadata.itemWidth, height: height)
        }
    }

    private func includeHeaderLayoutInto(_ layout: inout ActivityFeedItemLayout,
                                         for content: ActivityFeedItemContent,
                                         metadata: ActivityFeedItemLayoutMetadata) {

        let contentWidth = metadata.itemWidth - metadata.contentInsets.left - metadata.contentInsets.right
        let boundingSize = CGSize(width: contentWidth,
                                  height: CGFloat.greatestFiniteMagnitude)

        let timestampAttributes = [NSAttributedString.Key.font: metadata.timestampFont]
        let timestampRect = (content.timestamp as NSString).boundingRect(with: boundingSize,
                                                                         options: metadata.drawingOptions,
                                                                         attributes: timestampAttributes,
                                                                         context: nil)
        layout.timestampSize = timestampRect.size

        layout.iconSize = content.icon?.size ?? .zero

        let typeAttributes = [NSAttributedString.Key.font: metadata.typeFont]

        var typeBoundingWidth = contentWidth - layout.timestampSize.width - metadata.typeTimestampSpacing

        if content.icon != nil {
            typeBoundingWidth += metadata.iconTypeSpacing + layout.iconSize.width
        }

        let typeBoundingSize = CGSize(width: min(typeBoundingWidth, contentWidth), height: boundingSize.height)
        let typeRect = (content.type as NSString).boundingRect(with: typeBoundingSize,
                                                               options: metadata.drawingOptions,
                                                               attributes: typeAttributes,
                                                               context: nil)

        layout.typeSize = typeRect.size
    }

    private func includeTitleLayoutInto(_ layout: inout ActivityFeedItemLayout,
                                        title: String,
                                        metadata: ActivityFeedItemLayoutMetadata) {
        let contentWidth = metadata.itemWidth - metadata.contentInsets.left - metadata.contentInsets.right
        let boundingSize = CGSize(width: contentWidth,
                                  height: CGFloat.greatestFiniteMagnitude)

        let titleAttributes = [NSAttributedString.Key.font: metadata.titleFont]
        let titleRect = (title as NSString).boundingRect(with: boundingSize,
                                                         options: metadata.drawingOptions,
                                                         attributes: titleAttributes,
                                                         context: nil)

        layout.titleSize = titleRect.size
    }

    private func includeDetailsLayoutInto(_ layout: inout ActivityFeedItemLayout,
                                          details: String,
                                          metadata: ActivityFeedItemLayoutMetadata) {
        let contentWidth = metadata.itemWidth - metadata.contentInsets.left - metadata.contentInsets.right
        let boundingSize = CGSize(width: contentWidth,
                                  height: CGFloat.greatestFiniteMagnitude)

        let detailsAttributes = [NSAttributedString.Key.font: metadata.detailsFont]
        let detailsRect = (details as NSString).boundingRect(with: boundingSize,
                                                             options: metadata.drawingOptions,
                                                             attributes: detailsAttributes,
                                                             context: nil)

        layout.detailsSize = detailsRect.size
    }
}
