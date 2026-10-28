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

struct ActivityUserData: Codable, Equatable {
    var firstName: String
    var lastName: String
}

struct ActivityProjectData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case name = "projectName"
    }

    var name: String
}

struct ActivityData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case events = "activity"
        case users = "usersDict"
        case projects = "projectsDict"
    }

    var events: [ActivityOneOfEventData]
    var users: [String: ActivityUserData]?
    var projects: [String: ActivityProjectData]?
}

extension ActivityData {
    static var empty: ActivityData {
        return ActivityData(events: [], users: nil, projects: nil)
    }
}
