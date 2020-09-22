/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class ActivityFeedAmountCollectionViewCell: UICollectionViewCell {
    private(set) var viewModel: ActivityFeedAmountItemViewModelProtocol?
    private(set) var layoutMetadata: ActivityFeedAmountItemLayoutMetadata?

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        backgroundColor = .clear
    }

    func bind(viewModel: ActivityFeedAmountItemViewModelProtocol,
              with layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {
        self.viewModel = viewModel
        self.layoutMetadata = layoutMetadata

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let content = viewModel?.content, let layout = viewModel?.layout else {
            return
        }

        guard let layoutMetadata = layoutMetadata else {
            return
        }

        if let icon = content.icon {
            draw(rect, icon: icon, layout: layout, layoutMetadata: layoutMetadata)
        }

        draw(rect, type: content.type as NSString, layout: layout, layoutMetadata: layoutMetadata)
        draw(rect, timestamp: content.timestamp as NSString, layout: layout, layoutMetadata: layoutMetadata)
        draw(rect, details: content.details as NSString, layout: layout, layoutMetadata: layoutMetadata)

        if let amountStateIcon = content.amountStateIcon {
            draw(rect, amountStateIcon: amountStateIcon, layout: layout, layoutMetadata: layoutMetadata)
        }

        draw(rect, amountText: content.amountText as NSString, layout: layout, layoutMetadata: layoutMetadata)

        if let amountSymbolIcon = content.amountSymbolIcon {
            draw(rect, amountSymbolIcon: amountSymbolIcon, layout: layout, layoutMetadata: layoutMetadata)
        }
    }

    private func draw(_ rect: CGRect,
                      icon: UIImage,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {

        let offsetX = layoutMetadata.contentInsets.left

        let lineHeight = layout.itemHeaderHeight

        let offsetY = layoutMetadata.contentInsets.top + lineHeight / 2.0 - layout.iconSize.height / 2.0

        icon.draw(in: CGRect(x: offsetX, y: offsetY, width: icon.size.width, height: icon.size.height))
    }

    private func draw(_ rect: CGRect,
                      type: NSString,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {

        var offsetX: CGFloat

        if layout.iconSize.width > 0.0 {
            offsetX = layoutMetadata.contentInsets.left + layout.iconSize.width
                + layoutMetadata.iconTypeSpacing
        } else {
            offsetX = layoutMetadata.contentInsets.left
        }

        let lineHeight = layout.itemHeaderHeight

        let offsetY = layoutMetadata.contentInsets.top + lineHeight / 2.0 - layout.typeSize.height / 2.0

        let typeRect = CGRect(x: offsetX,
                              y: offsetY,
                              width: layout.typeSize.width,
                              height: layout.typeSize.height)

        let typeAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: layoutMetadata.typeFont,
            NSAttributedString.Key.foregroundColor: UIColor.activityType
        ]

        type.draw(with: typeRect,
                  options: layoutMetadata.drawingOptions,
                  attributes: typeAttributes,
                  context: nil)
    }

    private func draw(_ rect: CGRect,
                      timestamp: NSString,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {

        let offsetX = rect.maxX - layoutMetadata.contentInsets.right - layout.timestampSize.width

        let lineHeight = layout.itemHeaderHeight

        let offsetY = layoutMetadata.contentInsets.top + lineHeight / 2.0 - layout.timestampSize.height / 2.0

        let timestampRect = CGRect(x: offsetX,
                                   y: offsetY,
                                   width: layout.timestampSize.width,
                                   height: layout.timestampSize.height)

        let typeAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: layoutMetadata.timestampFont,
            NSAttributedString.Key.foregroundColor: UIColor.activityTimestamp
        ]

        timestamp.draw(with: timestampRect,
                       options: layoutMetadata.drawingOptions,
                       attributes: typeAttributes,
                       context: nil)
    }

    private func draw(_ rect: CGRect,
                      details: NSString,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {

        let detailsOriginY = layoutMetadata.contentInsets.top + layout.itemHeaderHeight
            + layoutMetadata.detailsTopSpacing

        let detailsRect = CGRect(x: layoutMetadata.contentInsets.left,
                                 y: detailsOriginY,
                                 width: layout.detailsSize.width,
                                 height: layout.detailsSize.height)

        let detailsAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: layoutMetadata.detailsFont,
            NSAttributedString.Key.foregroundColor: UIColor.activityDetails
        ]

        details.draw(with: detailsRect,
                     options: layoutMetadata.drawingOptions,
                     attributes: detailsAttributes,
                     context: nil)
    }

    private func draw(_ rect: CGRect,
                      amountStateIcon: UIImage,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {

        var offsetX = rect.maxX - layoutMetadata.contentInsets.right
            - layout.amountSymbolSize.width - layout.amountTextSize.width
            - layoutMetadata.amountStateIconTexSpacing - layout.amountStateIconSize.width

        if layout.amountSymbolSize != .zero {
            offsetX -= layoutMetadata.amountTexSymbolSpacing
        }

        let offsetY = layoutMetadata.contentInsets.top + layout.itemHeaderHeight + layoutMetadata.detailsTopSpacing
            + layout.detailsSize.height / 2.0 - layout.amountStateIconSize.height / 2.0

        amountStateIcon.draw(in: CGRect(x: offsetX, y: offsetY, width: layout.amountStateIconSize.width,
                                        height: layout.amountStateIconSize.height))
    }

    private func draw(_ rect: CGRect,
                      amountText: NSString,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {

        var offsetX = rect.maxX - layoutMetadata.contentInsets.right
            - layout.amountSymbolSize.width - layout.amountTextSize.width

        if layout.amountSymbolSize != .zero {
            offsetX -= layoutMetadata.amountTexSymbolSpacing
        }

        let offsetY = layoutMetadata.contentInsets.top + layout.itemHeaderHeight + layoutMetadata.detailsTopSpacing
            + layout.detailsSize.height / 2.0 - layout.amountTextSize.height / 2.0

        let amountAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: layoutMetadata.amountFont,
            NSAttributedString.Key.foregroundColor: UIColor.activityAmount
        ]

        let amountTextRect = CGRect(x: offsetX, y: offsetY,
                                    width: layout.amountTextSize.width,
                                    height: layout.amountTextSize.height)
        amountText.draw(in: amountTextRect, withAttributes: amountAttributes)
    }

    private func draw(_ rect: CGRect,
                      amountSymbolIcon: UIImage,
                      layout: ActivityFeedAmountItemLayout,
                      layoutMetadata: ActivityFeedAmountItemLayoutMetadata) {
        let offsetX = rect.maxX - layoutMetadata.contentInsets.right
            - layout.amountSymbolSize.width

        let offsetY = layoutMetadata.contentInsets.top + layout.itemHeaderHeight + layoutMetadata.detailsTopSpacing
            + layout.detailsSize.height / 2.0 - layout.amountSymbolSize.height / 2.0

        let amountSymbolRect = CGRect(origin: CGPoint(x: offsetX, y: offsetY), size: layout.amountSymbolSize)
        amountSymbolIcon.draw(in: amountSymbolRect)
    }
}
