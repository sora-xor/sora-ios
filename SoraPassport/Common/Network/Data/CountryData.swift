/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum Csp: String, Codable {
    case supported = "true"
    case unsupported = "false"
}

struct CountryItemData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case name
        case dialCode = "dial_code"
        case csp
    }

    var name: String
    var dialCode: String
    var csp: Csp
}

struct CountryData: Codable, Equatable {
    var sectionName: String
    var topics: [String: CountryItemData]
}
