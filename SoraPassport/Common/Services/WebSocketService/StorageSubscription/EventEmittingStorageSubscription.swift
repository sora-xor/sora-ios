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
import RobinHood

typealias EventEmittingFactoryClosure = (DataProviderChange<ChainStorageItem>) -> EventProtocol

final class EventEmittingStorageSubscription: BaseStorageChildSubscription {
    let eventCenter: EventCenterProtocol

    let eventFactory: EventEmittingFactoryClosure

    init(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol,
        eventFactory: @escaping EventEmittingFactoryClosure
    ) {
        self.eventCenter = eventCenter
        self.eventFactory = eventFactory

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash _: Data?) {
        if case let .success(optionalChange) = result, let change = optionalChange {
            DispatchQueue.main.async {
                let event = self.eventFactory(change)
                self.eventCenter.notify(with: event)
            }
        }
    }
}
