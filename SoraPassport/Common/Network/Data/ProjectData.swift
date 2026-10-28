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

enum ProjectDataStatus: String, Codable {
    case open = "OPEN"
    case failed = "FAILED"
    case closed = "COMPLETED"
}

struct ProjectData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case favorite
        case favoriteCount
        case unwatched
        case name
        case description
        case imageLink
        case link = "projectLink"
        case fundingTarget
        case fundingCurrent
        case fundingDeadline
        case status
        case statusUpdateTime
        case votedFriendsCount
        case votes
    }

    var identifier: String
    var favorite: Bool
    var favoriteCount: Int32
    var unwatched: Bool
    var name: String
    var description: String?
    var imageLink: URL?
    var link: URL?
    var fundingTarget: String
    var fundingCurrent: String
    var fundingDeadline: Int64
    var status: ProjectDataStatus
    var statusUpdateTime: Int64
    var votedFriendsCount: Int32
    var votes: String
}

extension ProjectData {
    var isVoted: Bool {
        if let votesDecimal = Decimal(string: votes), votesDecimal > 0.0 {
            return true
        } else {
            return false
        }
    }
}
