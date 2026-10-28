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

enum WalletBalanceFetchMock: FireMockProtocol {
    case invalidParameters
    case zero
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .invalidParameters:
            return 400
        default:
            return 200
        }
    }

    func mockFile() -> String {
        switch self {
        case .invalidParameters:
            return R.file.emptyResponseJson.fullName
        case .zero:
            return R.file.walletBalanceZeroResponseJson.fullName
        case .success:
            return R.file.walletBalanceResponseJson.fullName
        }
    }
}

//extension WalletBalanceFetchMock {
//    static func register(mock: WalletBalanceFetchMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.balance.rawValue) else {
//            Logger.shared.warning("Can't find wallet balance service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create balance fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
//    }
//}
