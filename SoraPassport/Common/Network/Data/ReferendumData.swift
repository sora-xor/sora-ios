// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

enum ReferendumDataStatus: String, Codable {
    case open = "CREATED"
    case rejected = "REJECTED"
    case accepted = "ACCEPTED"
}

struct ReferendumData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name
        case shortDescription = "description"
        case detailedDescription
        case fundingDeadline
        case statusUpdateTime
        case imageLink
        case status
        case supportVotes
        case opposeVotes
        case userSupportVotes
        case userOpposeVotes
    }

    let identifier: String
    let name: String
    let shortDescription: String
    let detailedDescription: String
    let fundingDeadline: Int64
    let statusUpdateTime: Int64
    let imageLink: URL?
    let status: ReferendumDataStatus
    let supportVotes: String
    let opposeVotes: String
    let userSupportVotes: String
    let userOpposeVotes: String
}
