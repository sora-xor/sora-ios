/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import FireMock

enum WalletBalanceFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.walletBalanceResponseJson.fullName
    }
}

extension WalletBalanceFetchMock {
    static func register(mock: WalletBalanceFetchMock, walletUnit: ServiceUnit) {
        guard let service = walletUnit.service(for: WalletServiceType.balance.rawValue) else {
            Logger.shared.warning("Can't find wallet balance service endpoint to mock")
            return
        }

        guard let url = URL(string: service.serviceEndpoint) else {
            Logger.shared.warning("Can't create balance fetch url")
            return
        }

        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
    }
}
