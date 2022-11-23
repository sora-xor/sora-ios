/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto
import FearlessUtils

protocol WebSocketServiceStateListener: AnyObject {
    func websocketNetworkDown(url: URL)
}

protocol WebSocketServiceProtocol: ApplicationServiceProtocol {
    var connection: JSONRPCEngine? { get }

    func update(settings: WebSocketServiceSettings)
    func addStateListener(_ listener: WebSocketServiceStateListener)
    func removeStateListener(_ listener: WebSocketServiceStateListener)
}

struct WebSocketServiceSettings: Equatable {
    let url: URL
    let addressType: SNAddressType?
    let address: String?
}
