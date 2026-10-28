/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct TransferPayload {
    public let receiveInfo: ReceiveInfo
    public let receiverName: String
    public let context: [String: String]?

    public init(receiveInfo: ReceiveInfo, receiverName: String, context: [String: String] = [:]) {
        self.receiveInfo = receiveInfo
        self.receiverName = receiverName
        self.context = context
    }
}
