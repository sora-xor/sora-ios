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
import SSFUtils
import IrohaCrypto
import RobinHood

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    let storageKeyFactory = StorageKeyFactory()
    let addressFactory = SS58AddressFactory()
    let operationManager = OperationManagerFacade.sharedManager
    let eventCenter = EventCenter.shared
    let logger = Logger.shared

    var runtimeService: RuntimeCodingServiceProtocol? {
        ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
    }

    let providerFactory: SubstrateDataProviderFactoryProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
        providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )
    }

    func createStartSubscriptions(
        type: SNAddressType,
        engine: JSONRPCEngine
    ) throws -> [WebSocketSubscribing] {
        let runtimeSubscription = createRuntimeVersionSubscription(
            engine: engine,
            networkType: type
        )
        return [runtimeSubscription]
    }

    func createSubscriptions(
        address: String,
        type: SNAddressType,
        engine: JSONRPCEngine
    ) throws -> [WebSocketSubscribing] {
        let accountId = try addressFactory.accountId(fromAddress: address, type: type)

        let localStorageIdFactory = try ChainStorageIdFactory(chain: type.chain)

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: operationManager,
            eventCenter: eventCenter,
            localKeyFactory: localStorageIdFactory,
            logger: logger
        )

        let transferSubscription = createTransferSubscription(
            address: address,
            engine: engine,
            networkType: type
        )

        let accountSubscription =
            try createAccountInfoSubscription(
                transferSubscription: transferSubscription,
                accountId: accountId,
                localStorageIdFactory: localStorageIdFactory
            )

        let accountSubscriptions: [StorageChildSubscribing] = [
            accountSubscription
        ]

        let globalSubscriptions = try createGlobalSubscriptions(childSubscriptionFactory)

        let globalSubscriptionContainer = StorageSubscriptionContainer(
            engine: engine,
            children: globalSubscriptions,
            logger: Logger.shared
        )

        let accountSubscriptionContainer = StorageSubscriptionContainer(
            engine: engine,
            children: accountSubscriptions,
            logger: Logger.shared
        )

        let runtimeSubscription = createRuntimeVersionSubscription(
            engine: engine,
            networkType: type
        )
        
        let blockSubscription =
            try createAccountInfoSubscription(
                transferSubscription: transferSubscription,
                accountId: accountId,
                localStorageIdFactory: localStorageIdFactory
            )

//        let electionStatusSubscription = try createElectionStatusSubscription(
//            childSubscriptionFactory,
//            engine: engine
//        )
//
//        let stakingResolver = createStakingResolver(
//            address: address,
//            childSubscriptionFactory: childSubscriptionFactory,
//            engine: engine,
//            networkType: type
//        )
//
//        let stakingSubscription =
//            createStakingSubscription(
//                address: address,
//                engine: engine,
//                childSubscriptionFactory: childSubscriptionFactory,
//                networkType: type
//            )

        return [globalSubscriptionContainer,
                accountSubscriptionContainer,
                runtimeSubscription
//                electionStatusSubscription,
//                stakingResolver,
//                stakingSubscription
        ]
    }

    private func createGlobalSubscriptions(_ factory: ChildSubscriptionFactoryProtocol)
        throws -> [StorageChildSubscribing] {
        let upgradeV28Subscription = try createV28Subscription(factory)

        let activeEraSubscription = try createActiveEraSubscription(factory)

        let currentEraSubscription = try createCurrentEraSubscription(factory)

        let totalIssuanceSubscription = try createTotalIssuanceSubscription(factory)
            
        let newBlockSubscription = try createNewBlockSubscription(factory)

//        let historyDepthSubscription = try createHistoryDepthSubscription(factory)

        let subscriptions: [StorageChildSubscribing] = [
            upgradeV28Subscription,
            activeEraSubscription,
            currentEraSubscription,
            totalIssuanceSubscription,
            newBlockSubscription
//            historyDepthSubscription
        ]

        return subscriptions
    }

    private func createAccountInfoSubscription(
        transferSubscription: TransactionSubscription,
        accountId: Data,
        localStorageIdFactory: ChainStorageIdFactoryProtocol
    ) throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let localStorageKey = localStorageIdFactory.createIdentifier(for: accountStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AccountInfoSubscription(
            transferSubscription: transferSubscription,
            remoteStorageKey: accountStorageKey,
            localStorageKey: localStorageKey,
            storage: AnyDataProviderRepository(storage),
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared,
            eventCenter: EventCenter.shared
        )
    }

    private func createActiveEraSubscription(_ factory: ChildSubscriptionFactoryProtocol)
        throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.activeEra()

        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createCurrentEraSubscription(_ childFactory: ChildSubscriptionFactoryProtocol)
        throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.currentEra()
        return childFactory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createTotalIssuanceSubscription(_ factory: ChildSubscriptionFactoryProtocol)
        throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.totalIssuance()

        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }
    
    private func createNewBlockSubscription(_ factory: ChildSubscriptionFactoryProtocol)
        throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.newBlock()

        return factory.createEventEmittingSubscription(remoteKey: remoteStorageKey) { _ in
            return NewBlockEvent()
        }
    }
    

//    private func createElectionStatusSubscription(
//        _ factory: ChildSubscriptionFactoryProtocol,
//        engine: JSONRPCEngine
//    )
//        throws -> WebSocketSubscribing {
//        let subscription = ElectionStatusSubscription(
//            engine: engine,
//            runtimeService: runtimeService,
//            childSubscriptionFactory: factory,
//            operationManager: operationManager,
//            logger: logger
//        )
//
//        return subscription
//    }

    private func createV28Subscription(_ factory: ChildSubscriptionFactoryProtocol)
        throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.updatedDualRefCount()

        return factory.createEventEmittingSubscription(remoteKey: remoteStorageKey) { _ in
            WalletBalanceChanged()
        }
    }

    private func createTransferSubscription(
        address: String,
        engine: JSONRPCEngine,
        networkType: SNAddressType
    ) -> TransactionSubscription {
        let filter = NSPredicate.filterTransactionsBy(address: address)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            storageFacade.createRepository(filter: filter)

        let contactOperationFactory = WalletContactOperationFactory(
            storageFacade: storageFacade,
            targetAddress: address
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: storageKeyFactory,
            operationManager: operationManager
        )

        return TransactionSubscription(
            engine: engine,
            address: address,
            chain: networkType.chain,
            addressFactory: addressFactory,
            runtimeService: runtimeService!,
            txStorage: AnyDataProviderRepository(txStorage),
            contactOperationFactory: contactOperationFactory,
            storageRequestFactory: storageRequestFactory,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }

    private func createRuntimeVersionSubscription(
        engine: JSONRPCEngine,
        networkType: SNAddressType
    ) -> RuntimeVersionSubscription {
        let chain = networkType.chain
        logger.info("Runtime subscription gen: \(chain.genesisHash())" )
        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: chain.genesisHash())
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository(filter: filter)

        return RuntimeVersionSubscription(
            chain: chain,
            storage: AnyDataProviderRepository(storage),
            engine: engine,
            operationManager: operationManager,
            logger: logger
        )
    }

//    private func createStakingResolver(
//        address: String,
//        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
//        engine: JSONRPCEngine,
//        networkType: SNAddressType
//    ) -> StakingAccountResolver {
//        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
//            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))
//
//        let filter = NSPredicate.filterByStashOrController(address)
//        let repository: CoreDataRepository<StashItem, CDStashItem> = storageFacade
//            .createRepository(
//                filter: filter,
//                sortDescriptors: [],
//                mapper: AnyCoreDataMapper(mapper)
//            )
//
//        return StakingAccountResolver(
//            address: address,
//            chain: networkType.chain,
//            engine: engine,
//            runtimeService: runtimeService,
//            repository: AnyDataProviderRepository(repository),
//            childSubscriptionFactory: childSubscriptionFactory,
//            addressFactory: addressFactory,
//            operationManager: operationManager,
//            logger: logger
//        )
//    }

//    private func createStakingSubscription(
//        address: String,
//        engine: JSONRPCEngine,
//        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
//        networkType: SNAddressType
//    ) -> StakingAccountSubscription {
//        let provider = providerFactory.createStashItemProvider(for: address)
//
//        return StakingAccountSubscription(
//            address: address,
//            chain: networkType.chain,
//            engine: engine,
//            provider: provider,
//            runtimeService: runtimeService,
//            childSubscriptionFactory: childSubscriptionFactory,
//            operationManager: operationManager,
//            addressFactory: addressFactory,
//            logger: logger
//        )
//    }
//
//    private func createHistoryDepthSubscription(
//        _ factory: ChildSubscriptionFactoryProtocol
//    ) throws -> StorageChildSubscribing {
//        let remoteStorageKey = try storageKeyFactory.historyDepth()
//        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
//    }
}
