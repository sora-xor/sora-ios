/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import CommonWallet

final class WalletHeaderViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = R.reuseIdentifier.walletAccountHeaderId.identifier

    var itemHeight: CGFloat = 73.0

    var walletController: UINavigationController?
    private(set) var walletWireframe: WalletWireframeProtocol

    init(walletWireframe: WalletWireframeProtocol) {
        self.walletWireframe = walletWireframe
    }

    public func presentHelp() {
        if let navigationController = walletController {
            walletWireframe.presentHelp(in: navigationController)
        }
    }

    func didSelect() {}
}
