/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletTransactionsViewModel {
    let ethereumCommand: WalletCommandProtocol?
    let soranetCommand: WalletCommandProtocol?
}

extension WalletTransactionsViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let trasactionDetailsDefinition = definition as? WalletTransactionDetailsDefining {
            return trasactionDetailsDefinition.defineViewForTransactionsViewModel(self)
        } else {
            return nil
        }
    }
}
