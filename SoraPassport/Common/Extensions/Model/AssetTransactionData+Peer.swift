/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

extension AssetTransactionData {
    var peerEthereumAddress: String? {
        guard let type = WalletTransactionTypeValue(rawValue: type) else {
            return nil
        }

        switch type {
        case .incoming, .outgoing:
            if NSPredicate.ethereumAddress.evaluate(with: peerId) {
                return peerId
            } else {
                return nil
            }
        case .withdraw:
            if NSPredicate.ethereumAddress.evaluate(with: peerId) {
                return peerId
            } else if NSPredicate.ethereumAddress.evaluate(with: details) {
                return details
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}
