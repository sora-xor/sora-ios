/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

struct WalletEndpointMapping {
    var balance: String
    var history: String
    var search: String
    var transfer: String
    var transferMetadata: String
    var contacts: String
    var withdraw: String
    var withdrawalMetadata: String
}

final class WalletNetworkResolver {
    let endpointMapping: WalletEndpointMapping
    let requestSigner: NetworkRequestModifierProtocol

    init(endpointMapping: WalletEndpointMapping, requestSigner: NetworkRequestModifierProtocol) {
        self.endpointMapping = endpointMapping
        self.requestSigner = requestSigner
    }
}

extension WalletNetworkResolver: WalletNetworkResolverProtocol {
    func urlTemplate(for type: WalletRequestType) -> String {
        switch type {
        case .balance:
            return endpointMapping.balance
        case .history:
            return endpointMapping.history
        case .search:
            return endpointMapping.search
        case .transfer:
            return endpointMapping.transfer
        case .transferMetadata:
            return endpointMapping.transferMetadata
        case .contacts:
            return endpointMapping.contacts
        case .withdraw:
            return endpointMapping.withdraw
        case .withdrawalMetadata:
            return endpointMapping.withdrawalMetadata
        }
    }

    func adapter(for type: WalletRequestType) -> NetworkRequestModifierProtocol? {
        return requestSigner
    }
}
