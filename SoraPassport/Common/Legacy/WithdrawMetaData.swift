/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct WithdrawMetaData: Codable, Equatable {
    public var providerAccountId: String
    public var feeDescriptions: [FeeDescription]

    public init(providerAccountId: String, feeDescriptions: [FeeDescription]) {
        self.providerAccountId = providerAccountId
        self.feeDescriptions = feeDescriptions
    }
}
