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
import RobinHood
import FireMock

enum ReferendumsVotedFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.votedReferendumsResponseJson.fullName
    }
}

//extension ReferendumsVotedFetchMock {
//    static func register(mock: ReferendumsVotedFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.referendumsVoted.rawValue) else {
//            Logger.shared.warning("Can't find voted referendums fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create voted referendums fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
