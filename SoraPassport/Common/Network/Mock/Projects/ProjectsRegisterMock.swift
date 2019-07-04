/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import FireMock

enum ProjectsRegisterMock: FireMockProtocol {
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

extension ProjectsRegisterMock {
    static func register(mock: ProjectsRegisterMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.register.rawValue) else {
            Logger.shared.warning("Can't find project registration service endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create registration regex")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
    }
}
