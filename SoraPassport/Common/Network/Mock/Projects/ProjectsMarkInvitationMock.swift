/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FireMock

enum ProjectsMarkInvitationMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.successResultJson.fullName
    }
}

extension ProjectsMarkInvitationMock {
    static func register(mock: ProjectsMarkInvitationMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.markInvitation.rawValue) else {
            Logger.shared.warning("Can't find project invitation mark service endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create invitation mark regex")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .put)
    }
}
