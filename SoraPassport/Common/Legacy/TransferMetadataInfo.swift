/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct TransferMetadataInfo {
    public var assetId: String
    public var sender: String
    public var receiver: String

    public init(assetId: String, sender: String, receiver: String) {
        self.assetId = assetId
        self.sender = sender
        self.receiver = receiver
    }
}
