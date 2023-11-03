// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import FearlessUtils
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
