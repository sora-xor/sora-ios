/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

protocol WebSocketServiceProtocol: ApplicationServiceProtocol {
    var connection: JSONRPCEngine? { get }

    func update(settings: WebSocketServiceSettings)
}

struct WebSocketServiceSettings: Equatable {
    let url: URL
    let addressType: SNAddressType?
    let address: String?
}
