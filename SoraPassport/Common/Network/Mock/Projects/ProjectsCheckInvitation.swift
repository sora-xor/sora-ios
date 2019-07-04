/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import FireMock

enum ProjectsCheckInvitationMock: FireMockProtocol {
    case successWithForm
    case successEmpty
    case successNil
    case invalid

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .successWithForm:
            return R.file.invitationCheckWithFormJson.fullName
        case .successEmpty:
            return R.file.invitationCheckWithEmptyFormJson.fullName
        case .successNil:
            return R.file.successResultJson.fullName
        case .invalid:
            return R.file.invalidInvitationCodeJson.fullName
        }
    }
}

extension ProjectsCheckInvitationMock {
    static func register(mock: ProjectsCheckInvitationMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.checkInvitation.rawValue) else {
            Logger.shared.warning("Can't find check invitation service endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create invitation check regex")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
    }
}
