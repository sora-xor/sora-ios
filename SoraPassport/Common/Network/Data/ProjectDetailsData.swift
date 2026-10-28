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

struct ProjectDetailsData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case title = "name"
        case annotation = "description"
        case discussionLink
        case favorite
        case favoriteCount
        case votedFriendsCount
        case details = "detailedDescription"
        case fundingTarget
        case fundingCurrent
        case fundingDeadline
        case imageLink
        case link = "projectLink"
        case email
        case gallery
        case status
        case statusUpdateTime
        case votes
    }

    var identifier: String
    var title: String
    var annotation: String
    var details: String?
    var discussionLink: LinkData?
    var favorite: Bool
    var favoriteCount: Int32
    var votedFriendsCount: Int32
    var fundingTarget: String
    var fundingCurrent: String
    var fundingDeadline: Int64
    var imageLink: URL?
    var link: URL?
    var email: String?
    var gallery: [MediaItemData]?
    var status: ProjectDataStatus
    var statusUpdateTime: Int64
    var votes: String
}

extension ProjectDetailsData {
    var isVoted: Bool {
        if let votesDecimal = Decimal(string: votes), votesDecimal > 0.0 {
            return true
        } else {
            return false
        }
    }
}
