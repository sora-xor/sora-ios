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
            let operation = (self.networkOperationFactory as? WalletNetworkFacade)?.fetchBalanceOperation(assets, onlyVisible: onlyVisible)
            return operation!
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
