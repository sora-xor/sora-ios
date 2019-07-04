/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import CommonWallet

// TODO: Remove when send/receive feature is completed

final class WalletAccountActionsCell: UICollectionViewCell {
    var viewModel: WalletViewModelProtocol?
}

extension WalletAccountActionsCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        self.viewModel = viewModel
    }
}
