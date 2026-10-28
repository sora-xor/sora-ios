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
import CoreData
import SSFSingleValueCache

class BalanceProviderFactory {

    static let executionQueue: OperationQueue = OperationQueue()
    static let balanceSyncQueue = DispatchQueue(label: "co.jp.soramitsu.wallet.cache.balance.queue")
    static let contactsSyncQueue = DispatchQueue(label: "co.jp.soramitsu.wallet.cache.contact.queue")

    let accountId: String
    let networkOperationFactory: WalletNetworkOperationFactoryProtocol
    let identifierFactory: SingleProviderIdentifierFactoryProtocol
    let cacheFacade: CoreDataCacheFacadeProtocol

    init(accountId: String,
         cacheFacade: CoreDataCacheFacadeProtocol,
         networkOperationFactory: WalletNetworkOperationFactoryProtocol,
         identifierFactory: SingleProviderIdentifierFactoryProtocol) {
        self.accountId = accountId
        self.cacheFacade = cacheFacade
        self.networkOperationFactory = networkOperationFactory
        self.identifierFactory = identifierFactory
    }

    public func createBalanceDataProvider(for assets: [AssetInfo], onlyVisible: Bool) throws -> SingleValueProvider<[BalanceData]> {
        let source: AnySingleValueProviderSource<[BalanceData]> = AnySingleValueProviderSource {
            let assets = assets.map { $0.assetId }
            // The provider keeps an asset whose balance could not be read,
            // marked as such; `AssetProvider` shows it as unavailable.
            if let facade = self.networkOperationFactory as? WalletNetworkFacade {
                return facade.fetchBalanceOperation(
                    assets,
                    onlyVisible: onlyVisible,
                    markingUnavailable: true
                )
            }
            return self.networkOperationFactory.fetchBalanceOperation(assets)
        }

        let updateTrigger = DataProviderEventTrigger.onInitialization

        let targetId = identifierFactory.balanceIdentifierForAccountId(accountId)

        let cache = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()

        return SingleValueProvider(targetIdentifier: targetId,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: updateTrigger,
                                   executionQueue: BalanceProviderFactory.executionQueue,
                                   serialSyncQueue: BalanceProviderFactory.balanceSyncQueue)
    }
    
    func createContactsDataProvider() throws -> SingleValueProvider<[SearchData]> {
        let source: AnySingleValueProviderSource<[SearchData]> = AnySingleValueProviderSource {
            let operation = self.networkOperationFactory.contactsOperation()
            return operation
        }
        
        let cache = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        
        let updateTrigger = DataProviderEventTrigger.onAddObserver

        let targetId = identifierFactory.contactsIdentifierForAccountId(accountId)

        return SingleValueProvider(targetIdentifier: targetId,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: updateTrigger,
                                   executionQueue: BalanceProviderFactory.executionQueue,
                                   serialSyncQueue: BalanceProviderFactory.contactsSyncQueue)
    }
}
