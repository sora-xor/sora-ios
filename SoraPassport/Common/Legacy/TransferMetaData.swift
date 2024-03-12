/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct TransferMetaData: Codable, Equatable {
    public var feeDescriptions: [FeeDescription]
    public var context: [String: String]?

    public init(feeDescriptions: [FeeDescription],
                context: [String: String]? = nil) {
        self.feeDescriptions = feeDescriptions
        self.context = context
    }
}
