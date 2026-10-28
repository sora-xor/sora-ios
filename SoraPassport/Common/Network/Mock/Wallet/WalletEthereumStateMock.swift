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

enum WalletEthereumStateMock: FireMockProtocol {
    case success
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.ethereumRegistrationStateJson.fullName
        case .notFound:
            return R.file.ethereumRegistrationNotFoundJson.fullName
        }
    }
}

//extension WalletEthereumStateMock {
//    static func register(mock: WalletEthereumStateMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.ethereumState.rawValue) else {
//            Logger.shared.warning("Can't find wallet ethereum state service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create transfer url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
