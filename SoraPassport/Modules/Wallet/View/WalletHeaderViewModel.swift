/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

final class WalletHeaderViewModel {
    weak var walletContext: CommonWalletContextProtocol?
    private(set) var walletWireframe: WalletWireframeProtocol

    init(walletWireframe: WalletWireframeProtocol) {
        self.walletWireframe = walletWireframe
    }

    public func presentHelp() {
        if let context = walletContext {

            walletWireframe.presentHelp(in: context)
        }
    }
}

extension WalletHeaderViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String {
        return R.reuseIdentifier.walletAccountHeaderId.identifier
    }

    var itemHeight: CGFloat {
        return 73.0
    }

    var command: WalletCommandProtocol? {
        let command = walletContext?.prepareScanReceiverCommand()
        command?.presentationStyle = .modal(inNavigation: true)
        return command
        
    }
}
