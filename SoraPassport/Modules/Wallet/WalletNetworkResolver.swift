/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import CommonWallet
import RobinHood

struct WalletEndpointMapping {
    var balance: String
    var history: String
    var search: String
    var transfer: String
    var contacts: String
}

final class WalletNetworkResolver {
    let enpointMapping: WalletEndpointMapping
    let requestSigner: NetworkRequestModifierProtocol

    init(enpointMapping: WalletEndpointMapping, requestSigner: NetworkRequestModifierProtocol) {
        self.enpointMapping = enpointMapping
        self.requestSigner = requestSigner
    }
}

extension WalletNetworkResolver: WalletNetworkResolverProtocol {
    func urlTemplate(for type: WalletRequestType) -> String {
        switch type {
        case .balance:
            return enpointMapping.balance
        case .history:
            return enpointMapping.history
        case .search:
            return enpointMapping.search
        case .transfer:
            return enpointMapping.transfer
        case .contacts:
            return enpointMapping.contacts
        }
    }

    func adapter(for type: WalletRequestType) -> NetworkRequestModifierProtocol? {
        return requestSigner
    }
}
