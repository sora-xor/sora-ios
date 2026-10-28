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

enum UserStorageVersion: String, CaseIterable {
    case version1 = "UserDataModel"
    case version2 = "UserDataModel 2"
//    case version3 = "MultiassetUserDataModel_v2"
//    case version4 = "MultiassetUserDataModel_v3"
//    case version5 = "MultiassetUserDataModel_v4"
//    case version6 = "MultiassetUserDataModel_v5"
//    case version7 = "MultiassetUserDataModel_v6"

    // Pin the production destination explicitly. Enumeration order is a source-code detail and
    // must never decide which schema receives an installed wallet or turn an upgrade into a
    // process-terminating path.
    static let current: UserStorageVersion = .version2

    func nextVersion() -> UserStorageVersion? {
        switch self {
        case .version1:
            return .version2
//        case .version2:
//            return .version3
//        case .version3:
//            return .version4
//        case .version4:
//            return .version5
//        case .version5:
//            return .version6
//        case .version6:
//            return .version7
//        case .version7:
//            return nil
        default:
            return nil
        }
    }
}
