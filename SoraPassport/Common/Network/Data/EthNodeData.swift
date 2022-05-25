/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct EthNodeData: Codable {
    let ethereumPassword: String
    let ethereumURL: String
    let etherscanBaseUrl: String
    let ethereumUsername, masterContractAddress: String

    enum CodingKeys: String, CodingKey {
        case ethereumPassword
        case ethereumURL = "ethereumUrl"
        case ethereumUsername, masterContractAddress, etherscanBaseUrl
    }
}
