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
import FireMock
import SoraFoundation

enum ActivityFeedMock: FireMockProtocol {
    case success
    case empty
    case internalError

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .success, .empty:
            return 200
        case .internalError:
            return 500
        }
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.activityFeedResponseJson.fullName
        case .empty:
            return R.file.activityFeedEmptyResponseJson.fullName
        case .internalError:
            return R.file.activityFeedEmptyResponseJson.fullName
        }
    }
}

//extension ActivityFeedMock {
//    static func register(mock: ActivityFeedMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.activityFeed.rawValue) else {
//            Logger.shared.warning("Can't find activity feed fetch endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create activity feed regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
