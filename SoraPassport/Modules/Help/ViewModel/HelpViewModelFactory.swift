/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol HelpViewModelFactoryProtocol: class {
    func createViewModel(from helpItem: HelpItemData, layoutMetadata: HelpItemLayoutMetadata) -> HelpViewModelProtocol
}

final class HelpViewModelFactory {
    private func createContent(from helpItem: HelpItemData) -> HelpViewModelContent {
        return HelpViewModelContent(title: helpItem.title, details: helpItem.description)
    }

    private func createLayout(from content: HelpViewModelContent,
                              layoutMetadata: HelpItemLayoutMetadata) -> HelpViewModelLayout {
        let boundingWidth = layoutMetadata.itemWidth -
            layoutMetadata.contentInset.left - layoutMetadata.contentInset.right
        let boundingSize = CGSize(width: boundingWidth, height: CGFloat.greatestFiniteMagnitude)

        var itemHeight = layoutMetadata.contentInset.top

        let titleAttributes = [NSAttributedString.Key.font: layoutMetadata.titleFont]
        let titleRect = (content.title as NSString).boundingRect(with: boundingSize,
                                                                 options: layoutMetadata.drawingOptions,
                                                                 attributes: titleAttributes,
                                                                 context: nil)

        itemHeight += titleRect.maxY + layoutMetadata.detailsTopSpacing

        let detailsAttributes = [NSAttributedString.Key.font: layoutMetadata.detailsFont]
        let detailsRect = (content.details as NSString).boundingRect(with: boundingSize,
                                                                     options: layoutMetadata.drawingOptions,
                                                                     attributes: detailsAttributes,
                                                                     context: nil)
        itemHeight += detailsRect.maxY + layoutMetadata.contentInset.bottom

        return HelpViewModelLayout(itemSize: CGSize(width: layoutMetadata.itemWidth, height: itemHeight),
                                   titleRect: titleRect,
                                   detailsRect: detailsRect)
    }
}

extension HelpViewModelFactory: HelpViewModelFactoryProtocol {
    func createViewModel(from helpItem: HelpItemData, layoutMetadata: HelpItemLayoutMetadata) -> HelpViewModelProtocol {
        let content = createContent(from: helpItem)
        let layout = createLayout(from: content, layoutMetadata: layoutMetadata)
        return HelpViewModel(content: content, layout: layout)
    }
}
