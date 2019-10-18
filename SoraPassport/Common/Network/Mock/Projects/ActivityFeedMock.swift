/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FireMock

enum ActivityFeedMock: FireMockProtocol {
    case success
    case empty

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.activityFeedResponseJson.fullName
        case .empty:
            return R.file.activityFeedEmptyResponseJson.fullName
        }
    }
}

extension ActivityFeedMock {
    static func register(mock: ActivityFeedMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.activityFeed.rawValue) else {
            Logger.shared.warning("Can't find activity feed fetch endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create activity feed regex")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
    }
}
