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

enum DecentralizedDocumentCreateMock: FireMockProtocol {
    case success
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .success:
            return 200
        case .notFound:
            return 404
        }
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.successResultJson.fullName
        case .notFound:
            return R.file.emptyResponseJson.fullName
        }

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
