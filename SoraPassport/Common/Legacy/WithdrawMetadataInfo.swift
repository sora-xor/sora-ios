/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct WithdrawMetadataInfo: Codable {
    public var assetId: String
    public var option: String

    public init(assetId: String, option: String) {
        self.assetId = assetId
        self.option = option
    }
}
