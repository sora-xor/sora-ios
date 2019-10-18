/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FireMock

enum ProjectsCustomerMock: FireMockProtocol {
    case success
    case resourceNotFound
    case unsupportedCountry

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .success, .unsupportedCountry:
            return 200
        case .resourceNotFound:
            return 404
        }
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.customerFetchResponseJson.fullName
        case .unsupportedCountry:
            return R.file.customerUnsupportedCountryResponseJson.fullName
        case .resourceNotFound:
            return R.file.emptyResponseJson.fullName
        }
    }
}

extension ProjectsCustomerMock {
    static func register(mock: ProjectsCustomerMock, projectUnit: ServiceUnit) {
        guard let service = projectUnit.service(for: ProjectServiceType.customer.rawValue) else {
            Logger.shared.warning("Can't find customer fetch service endpoint to mock")
            return
        }

        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
            Logger.shared.warning("Can't create customer fetch regex")
            return
        }

        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
    }
}
