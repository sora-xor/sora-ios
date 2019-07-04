/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import FireMock

enum DecentralizedDocumentCreateMock: FireMockProtocol {
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

extension DecentralizedDocumentCreateMock {
    @discardableResult
    static func register(mock: DecentralizedDocumentCreateMock) -> Bool {
        guard let serviceUrl = URL(string: ApplicationConfig.shared.didResolverUrl) else {
            return false
        }

        FireMock.register(mock: mock, forURL: serviceUrl, httpMethod: .post)

        return true
    }
}
