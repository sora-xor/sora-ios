/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

final class ReceiveHeaderView: UIView {
    @IBOutlet private(set) var accountView: DetailsRoundedView!

    var actionCommand: WalletCommandProtocol?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 144.0)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        accountView.addTarget(self, action: #selector(actionReceive), for: .touchUpInside)
    }

    @objc func actionReceive() {
        try? actionCommand?.execute()
    }
}
