/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto
import FearlessUtils

protocol WebSocketSubscribing {}

protocol WebSocketSubscriptionFactoryProtocol {
    func createStartSubscriptions(type: SNAddressType,
                                  engine: JSONRPCEngine) throws -> [WebSocketSubscribing]

    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing]
}
