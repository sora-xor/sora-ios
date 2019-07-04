/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

extension ActivityFeedViewModelFactory {
    func createLayout(for content: ActivityFeedAmountItemContent,
                      metadata: ActivityFeedAmountItemLayoutMetadata) -> ActivityFeedAmountItemLayout {
        var layout = ActivityFeedAmountItemLayout()

        var height = metadata.contentInsets.top + metadata.contentInsets.bottom

        includeHeaderLayoutInto(&layout, for: content, metadata: metadata)

        height += layout.itemHeaderHeight

        includeAmountLayoutInto(&layout, for: content, metadata: metadata)

        includeDetailsLayoutInto(&layout, details: content.details, metadata: metadata)
        height += metadata.detailsTopSpacing + layout.detailsSize.height

        return layout.with {
            $0.itemSize = CGSize(width: metadata.itemWidth, height: height)
        }
    }

    private func includeHeaderLayoutInto(_ layout: inout ActivityFeedAmountItemLayout,
                                         for content: ActivityFeedAmountItemContent,
                                         metadata: ActivityFeedAmountItemLayoutMetadata) {

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

    private func includeAmountLayoutInto(_ layout: inout ActivityFeedAmountItemLayout,
                                         for content: ActivityFeedAmountItemContent,
                                         metadata: ActivityFeedAmountItemLayoutMetadata) {
        layout.amountStateIconSize = content.amountStateIcon?.size ?? .zero
        layout.amountSymbolSize = content.amountSymbolIcon?.size ?? .zero

        let contentWidth = metadata.itemWidth - metadata.contentInsets.left - metadata.contentInsets.right
        let boundingSize = CGSize(width: contentWidth,
                                  height: CGFloat.greatestFiniteMagnitude)

        let amountAttributes = [NSAttributedString.Key.font: metadata.amountFont]
        let amountRect = (content.amountText as NSString).boundingRect(with: boundingSize,
                                                                       options: metadata.drawingOptions,
                                                                       attributes: amountAttributes,
                                                                       context: nil)
        layout.amountTextSize = amountRect.size
    }

    private func includeDetailsLayoutInto(_ layout: inout ActivityFeedAmountItemLayout,
                                          details: String,
                                          metadata: ActivityFeedAmountItemLayoutMetadata) {

        var contentWidth = metadata.itemWidth - metadata.contentInsets.left - metadata.contentInsets.right
            - layout.amountStateIconSize.width - layout.amountTextSize.width - layout.amountSymbolSize.width
            - metadata.detailsAmountSpacing

        if layout.amountStateIconSize != .zero {
            contentWidth -= metadata.amountStateIconTexSpacing
        }

        if layout.amountSymbolSize != .zero {
            contentWidth -= metadata.amountTexSymbolSpacing
        }

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
