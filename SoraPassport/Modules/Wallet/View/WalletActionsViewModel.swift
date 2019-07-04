/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import CommonWallet

// TODO: Remove when send/receive feature is completed
final class WalletActionsViewModel: ActionsViewModelProtocol {
    var sendTitle: String = ""
    var receiveTitle: String = ""
    var style: ActionsCellStyle = {
        let textStyle = WalletTextStyle(font: UIFont.systemFont(ofSize: 16), color: .white)
        return ActionsCellStyle(sendText: textStyle, receiveText: textStyle)
    }()

    weak var delegate: ActionsViewModelDelegate?

    var cellReuseIdentifier: String
    var itemHeight: CGFloat

    init(cellReuseIdentifier: String, itemHeight: CGFloat) {
        self.cellReuseIdentifier = cellReuseIdentifier
        self.itemHeight = itemHeight
    }

    func didSelect() {}
}
