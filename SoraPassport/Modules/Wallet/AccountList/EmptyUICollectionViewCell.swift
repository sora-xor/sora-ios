/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

class EmptyUICollectionViewCell: UICollectionViewCell, WalletViewProtocol {
    public var viewModel: WalletViewModelProtocol? {
        nil
    }

    public func bind(viewModel: WalletViewModelProtocol) {
        
    }
}
