/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension SingleValueProvider {
    var getAndRefreshOperation: BaseOperation<Model> {
        return SingleValueOperation(provider: self)
    }
}
