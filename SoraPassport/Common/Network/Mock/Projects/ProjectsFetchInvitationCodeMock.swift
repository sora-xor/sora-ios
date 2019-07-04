/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import FireMock

enum ProjectsFetchInvitationCodeMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.fetchInvitationCodeJson.fullName
    }
}

extension ProjectsFetchInvitationCodeMock {
    static func register(mock: ProjectsFetchInvitationCodeMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.fetchInvitation.rawValue) else {
            Logger.shared.warning("Can't find project invitation code service endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create invitation fetch reges")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
    }
}
