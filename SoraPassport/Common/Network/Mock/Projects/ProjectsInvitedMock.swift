/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import FireMock

enum ProjectsInvitedMock: FireMockProtocol {
    case successWithoutParent
    case successWithParent

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .successWithoutParent:
            return R.file.invitedFetchWithoutParentJson.fullName
        case .successWithParent:
            return R.file.invitedFetchWithParentJson.fullName
        }
    }
}

extension ProjectsInvitedMock {
    static func register(mock: ProjectsInvitedMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.fetchInvited.rawValue) else {
            Logger.shared.warning("Can't find invited service endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create invited fetch regex")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
    }
}
