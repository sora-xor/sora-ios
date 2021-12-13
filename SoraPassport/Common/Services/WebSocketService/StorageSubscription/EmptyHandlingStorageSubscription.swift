/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class EmptyHandlingStorageSubscription: BaseStorageChildSubscription {
    override func handle(result _: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash _: Data?) {
        logger.debug("Did handle update for key: \(remoteStorageKey.toHex(includePrefix: true))")
    }
}
