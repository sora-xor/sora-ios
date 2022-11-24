/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import FearlessUtils
import Foundation
import RobinHood
import XNetworking

protocol SubqueryPoolsFactoryProtocol {
    func getStrategicBonusAPYOperation() -> BaseOperation<[SbApyInfo]>
}

final class SubqueryPoolsFactory {
    let url: URL
    let filter: [String]

    init(url: URL, filter: [String] = []) {
        self.url = url
        self.filter = filter
    }
}

extension SubqueryPoolsFactory: SubqueryPoolsFactoryProtocol {
    func getStrategicBonusAPYOperation() -> BaseOperation<[SbApyInfo]> {
        return SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: self.url)
    }
}
