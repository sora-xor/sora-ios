/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class ActivityFeedCollectionViewCell: UICollectionViewCell {
    private(set) var viewModel: ActivityFeedItemViewModelProtocol?
    private(set) var layoutMetadata: ActivityFeedItemLayoutMetadata?

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

    func bind(viewModel: ActivityFeedItemViewModelProtocol, with layoutMetadata: ActivityFeedItemLayoutMetadata) {
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

        if let title = content.title {
            draw(rect, title: title as NSString, layout: layout, layoutMetadata: layoutMetadata)
        }

        if let details = content.details {
            draw(rect, details: details as NSString, layout: layout, layoutMetadata: layoutMetadata)
        }
    }

    private func draw(_ rect: CGRect,
                      icon: UIImage,
                      layout: ActivityFeedItemLayout,
                      layoutMetadata: ActivityFeedItemLayoutMetadata) {

        let offsetX = layoutMetadata.contentInsets.left

        let lineHeight = layout.itemHeaderHeight

        let offsetY = layoutMetadata.contentInsets.top + lineHeight / 2.0 - layout.iconSize.height / 2.0

        icon.draw(in: CGRect(x: offsetX, y: offsetY, width: icon.size.width, height: icon.size.height))
    }

    private func draw(_ rect: CGRect,
                      type: NSString,
                      layout: ActivityFeedItemLayout,
                      layoutMetadata: ActivityFeedItemLayoutMetadata) {

        var offsetX: CGFloat

        if layout.iconSize != .zero {
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
                      layout: ActivityFeedItemLayout,
                      layoutMetadata: ActivityFeedItemLayoutMetadata) {

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
                      title: NSString,
                      layout: ActivityFeedItemLayout,
                      layoutMetadata: ActivityFeedItemLayoutMetadata) {

        let firstLineHeight = layout.itemHeaderHeight

        var titleOriginY = layoutMetadata.contentInsets.top + firstLineHeight
        titleOriginY += layoutMetadata.titleTopSpacing

        let titleRect = CGRect(x: layoutMetadata.contentInsets.left,
                               y: titleOriginY,
                               width: layout.titleSize.width,
                               height: layout.titleSize.height)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: layoutMetadata.titleFont,
            NSAttributedString.Key.foregroundColor: UIColor.activityTitle
        ]

        title.draw(with: titleRect,
                   options: layoutMetadata.drawingOptions,
                   attributes: titleAttributes,
                   context: nil)
    }

    private func draw(_ rect: CGRect,
                      details: NSString,
                      layout: ActivityFeedItemLayout,
                      layoutMetadata: ActivityFeedItemLayoutMetadata) {

        let firstLineHeight = layout.itemHeaderHeight

        var detailsOriginY = layoutMetadata.contentInsets.top + firstLineHeight

        if layout.titleSize.height > 0.0 {
            detailsOriginY += layoutMetadata.titleTopSpacing + layout.titleSize.height
            detailsOriginY += layoutMetadata.detailsTopSpacing
        } else {
            detailsOriginY += layoutMetadata.titleTopSpacing
        }

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
}
