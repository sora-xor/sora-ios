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

protocol ChildSubscriptionFactoryProtocol {
    func createEventEmittingSubscription(
        remoteKey: Data,
        eventFactory: @escaping EventEmittingFactoryClosure
    )
        -> StorageChildSubscribing

    func createEmptyHandlingSubscription(remoteKey: Data) -> StorageChildSubscribing
}

final class ChildSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol
    let operationManager: OperationManagerProtocol
    let localKeyFactory: ChainStorageIdFactoryProtocol
    let eventCenter: EventCenterProtocol

    private lazy var repository: AnyDataProviderRepository<ChainStorageItem> = {
        let coreDataRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(coreDataRepository)
    }()

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        localKeyFactory: ChainStorageIdFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.localKeyFactory = localKeyFactory
        self.logger = logger
    }
}

extension ChildSubscriptionFactory: ChildSubscriptionFactoryProtocol {
    func createEventEmittingSubscription(
        remoteKey: Data,
        eventFactory: @escaping EventEmittingFactoryClosure
    ) -> StorageChildSubscribing {
        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        return EventEmittingStorageSubscription(
            remoteStorageKey: remoteKey,
            localStorageKey: localKey,
            storage: repository,
            operationManager: operationManager,
            logger: logger,
            eventCenter: eventCenter,
            eventFactory: eventFactory
        )
    }

    func createEmptyHandlingSubscription(remoteKey: Data) -> StorageChildSubscribing {
        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        return EmptyHandlingStorageSubscription(
            remoteStorageKey: remoteKey,
            localStorageKey: localKey,
            storage: repository,
            operationManager: operationManager,
            logger: logger
        )
    }
}
