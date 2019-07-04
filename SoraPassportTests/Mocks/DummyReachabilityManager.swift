/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import Cuckoo

final class DummyReachabilityFactory {
    static func createMock(returnIsReachable: Bool = true) -> MockReachabilityManagerProtocol {
        let mock = MockReachabilityManagerProtocol()

        stub(mock) { stub in
            when(stub).add(listener: any()).thenDoNothing()
            when(stub).remove(listener: any()).thenDoNothing()
            when(stub).isReachable.get.then {
                return returnIsReachable
            }
        }

        return mock
    }
}
