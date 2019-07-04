/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class HelpTableViewCell: UITableViewCell {
    private(set) var viewModel: HelpViewModelProtocol?
    private(set) var layoutMetadata: HelpItemLayoutMetadata?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        backgroundColor = .clear
    }

    func bind(viewModel: HelpViewModelProtocol, layoutMetadata: HelpItemLayoutMetadata) {
        self.viewModel = viewModel
        self.layoutMetadata = layoutMetadata

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let model = viewModel, let metadata = layoutMetadata else {
            return
        }

        draw(title: model.content.title as NSString, layout: model.layout, metadata: metadata)
        draw(details: model.content.details as NSString, layout: model.layout, metadata: metadata)

        if metadata.containsSeparator {
            drawSeparator(with: rect, metadata: metadata)
        }
    }

    private func draw(title: NSString, layout: HelpViewModelLayout, metadata: HelpItemLayoutMetadata) {
        let titleAttributes = [NSAttributedString.Key.foregroundColor: metadata.titleColor,
                               NSAttributedString.Key.font: metadata.titleFont]
        let titleDrawingRect = CGRect(x: metadata.contentInset.left + layout.titleRect.minX,
                                      y: metadata.contentInset.top + layout.titleRect.minY,
                                      width: layout.titleRect.width,
                                      height: layout.titleRect.height)
        title.draw(in: titleDrawingRect, withAttributes: titleAttributes)
    }

    private func draw(details: NSString, layout: HelpViewModelLayout, metadata: HelpItemLayoutMetadata) {
        let detailsAttributes = [NSAttributedString.Key.foregroundColor: metadata.detailsTitleColor,
                                 NSAttributedString.Key.font: metadata.detailsFont]

        var detailsOrigin = metadata.contentInset.top + layout.titleRect.maxY
        detailsOrigin += metadata.detailsTopSpacing + layout.detailsRect.minY
        let detailsDrawingRect = CGRect(x: metadata.contentInset.left + layout.detailsRect.minX,
                                        y: detailsOrigin,
                                        width: layout.detailsRect.width,
                                        height: layout.detailsRect.height)
        details.draw(in: detailsDrawingRect, withAttributes: detailsAttributes)
    }

    private func drawSeparator(with rect: CGRect, metadata: HelpItemLayoutMetadata) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setStrokeColor(metadata.separatorColor.cgColor)
        context.setLineWidth(metadata.separatorWidth)

        context.move(to: CGPoint(x: metadata.contentInset.left,
                                 y: rect.size.height - metadata.separatorBottomMargin))
        context.addLine(to: CGPoint(x: metadata.itemWidth - metadata.contentInset.right,
                                    y: rect.size.height - metadata.separatorBottomMargin))

        context.strokePath()
    }
}
