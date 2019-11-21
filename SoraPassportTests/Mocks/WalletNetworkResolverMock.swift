/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

final class WalletNetworkResolverMock: WalletNetworkResolverProtocol {
    var closureUrlResolver: ((WalletRequestType) -> String)?
    var closureAdapter: ((WalletRequestType) -> NetworkRequestModifierProtocol?)?

    init(urlResolver: @escaping (WalletRequestType) -> String) {
        closureUrlResolver = urlResolver
    }

    func urlTemplate(for type: WalletRequestType) -> String {
        return closureUrlResolver?(type) ?? ""
    }

    func adapter(for type: WalletRequestType) -> NetworkRequestModifierProtocol? {
        return closureAdapter?(type)
    }
}
