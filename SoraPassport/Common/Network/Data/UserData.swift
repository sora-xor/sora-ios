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

struct UserData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userId
        case firstName
        case lastName
        case username
        case inviteAcceptExpirationMoment
        case country
        case phone
        case parentId
        case status
        case services = "userServices"
        case values = "userValues"
    }

    var userId: String
    var firstName: String
    var lastName: String
    var username: String?
    var country: String?
    var phone: String?
    var inviteAcceptExpirationMoment: Int64?
    var parentId: String?
    var status: String?
    var services: [UserServiceData]?
    var values: UserValuesData
}

extension UserData {
    var canAcceptInvitation: Bool {
        guard parentId == nil else {
            return false
        }

        guard let inviteAcceptExpirationMoment = inviteAcceptExpirationMoment else {
            return true
        }

        return TimeInterval(inviteAcceptExpirationMoment) > Date().timeIntervalSince1970
    }

    var invitationExpirationInterval: TimeInterval? {
        guard parentId == nil, let moment = inviteAcceptExpirationMoment else {
            return nil
        }

        let currentTimestamp = Date().timeIntervalSince1970

        if TimeInterval(moment) > currentTimestamp {
            return TimeInterval(moment) - currentTimestamp
        } else {
            return nil
        }
    }
}
