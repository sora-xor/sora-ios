/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol AnnouncementViewModelFactoryProtocol: class {
    func createAnnouncementViewModel(from announcement: AnnouncementData,
                                     using metadata: AnnouncementItemLayoutMetadata)
        -> AnnouncementItemViewModelProtocol
}

final class AnnouncementViewModelFactory: AnnouncementViewModelFactoryProtocol {
    func createAnnouncementViewModel(from announcement: AnnouncementData,
                                     using metadata: AnnouncementItemLayoutMetadata)
        -> AnnouncementItemViewModelProtocol {
        let boundingWidth = metadata.itemWidth - metadata.contentInsets.left -
                metadata.contentInsets.right
        let boundingSize = CGSize(width: boundingWidth,
                                  height: CGFloat.greatestFiniteMagnitude)

        let messageAttributes = [NSAttributedString.Key.font: metadata.messageFont]
        let messageSize = (announcement.message as NSString)
            .boundingRect(with: boundingSize,
                          options: metadata.drawingOptions,
                          attributes: messageAttributes,
                          context: nil).size

        let layout = AnnouncementItemLayout {
            let itemHeight = metadata.headerHeight + metadata.contentInsets.top +
                messageSize.height + metadata.contentInsets.bottom
            $0.itemSize = CGSize(width: metadata.itemWidth,
                                 height: itemHeight)
            $0.messageSize = messageSize
        }

        let content = AnnouncementItemContent(message: announcement.message)

        return AnnouncementItemViewModel(content: content,
                                         layout: layout)
    }
}
