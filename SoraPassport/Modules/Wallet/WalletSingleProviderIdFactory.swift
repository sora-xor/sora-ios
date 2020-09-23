/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletSingleProviderIdFactory: SingleProviderIdentifierFactoryProtocol {
    func transferMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                receiverId: String) -> String {
        if NSPredicate.ethereumAddress.evaluate(with: receiverId) {
            return "\(accountId)#\(assetId)#_ethereumMetadata"
        } else {
            return "\(accountId)#\(assetId)#_soranetMetadata"
        }
    }
}
