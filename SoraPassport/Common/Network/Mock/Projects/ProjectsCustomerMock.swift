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

enum ProjectsCustomerMock: FireMockProtocol {
    case successWithParent
    case successWithoutParent
    case successWithExpiredParentMoment
    case resourceNotFound
    case unauthorized

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .successWithParent, .successWithoutParent, .successWithExpiredParentMoment:
            return 200
        case .unauthorized:
            return 401
        case .resourceNotFound:
            return 404
        }
    }

    func mockFile() -> String {
        switch self {
        case .successWithParent:
            return R.file.customerFetchResponseJson.fullName
        case .successWithoutParent:
            return R.file.customerWithoutParentJson.fullName
        case .successWithExpiredParentMoment:
            return R.file.customerWithExpiredParentMomentJson.fullName
        case .resourceNotFound:
            return R.file.emptyResponseJson.fullName
        case .unauthorized:
            return R.file.emptyResponseJson.fullName
        }
    }
}

//extension ProjectsCustomerMock {
//    static func register(mock: ProjectsCustomerMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.customer.rawValue) else {
//            Logger.shared.warning("Can't find customer fetch service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create customer fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
