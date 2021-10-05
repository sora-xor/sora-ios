/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

public class MessageViewFactory: MessageViewFactoryProtocol {
    public func createMessageView() -> MessageViewProtocol {
        let messageView = MessageView()
        messageView.backgroundColor = UIColor.notificationBackground

        messageView.contentInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        messageView.horizontalSpacing = 12.0
        messageView.verticalSpacing = 2.0

        messageView.titleColor = UIColor.white
        messageView.titleFont = UIFont.notificationTitle

        messageView.subtitleColor = UIColor.white
        messageView.subtitleFont = UIFont.notificationSubtitle

        messageView.imageTintColor = UIColor.white

        return messageView
    }
}
