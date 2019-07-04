/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct HelpItemData: Codable, Equatable {
    var title: String
    var description: String
}

struct HelpData: Codable, Equatable {
    var sectionName: String
    var topics: [String: HelpItemData]
}
