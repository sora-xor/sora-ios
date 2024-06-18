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
import IrohaCrypto
import SSFUtils
import SSFSingleValueCache

typealias DecodedAccountInfo = ChainStorageDecodedItem<DyAccountInfo>

protocol SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData>
    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> DataProvider<DecodedAccountInfo>
}

final class SingleValueProviderFactory {
    static let shared = SingleValueProviderFactory(facade: SubstrateDataStorageFacade.shared,
                                                   operationManager: OperationManagerFacade.sharedManager,
                                                   logger: Logger.shared)

    private var providers: [String: WeakWrapper] = [:]

    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(facade: StorageFacadeProtocol, operationManager: OperationManagerProtocol, logger: LoggerProtocol) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
    }

    private func priceIdentifier(for assetId: WalletAssetId) -> String {
        assetId.rawValue + "PriceId"
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension SingleValueProviderFactory: SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = priceIdentifier(for: assetId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return AnySingleValueProvider(provider)
        }

        let repository = 
        SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()

        let source = CoingeckoPriceSource(assetId: assetId)

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }

    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> DataProvider<DecodedAccountInfo> {
        clearIfNeeded()

        let addressFactory = SS58AddressFactory()

        let addressType = try addressFactory.extractAddressType(from: address)
        let accountId = try addressFactory.accountId(fromAddress: address, type: addressType)

        let storageIdFactory = try ChainStorageIdFactory(chain: addressType.chain)

        let remoteKey = try StorageKeyFactory().accountInfoKeyForId(accountId)
        let localKey = storageIdFactory.createIdentifier(for: remoteKey)

        if let dataProvider = providers[localKey]?.target as? DataProvider<DecodedAccountInfo> {
            return dataProvider
        }

        let repository = InMemoryDataProviderRepository<ChainStorageDecodedItem<DyAccountInfo>>()

        let streamableProviderFactory = SubstrateDataProviderFactory(facade: facade,
                                                                     operationManager: operationManager,
                                                                     logger: logger)
        let streamableProvider = streamableProviderFactory.createStorageProvider(for: localKey)

        let trigger = DataProviderProxyTrigger()
        let source: StorageProviderSource<DyAccountInfo> =
            StorageProviderSource(itemIdentifier: localKey,
                                  codingPath: .account,
                                  runtimeService: runtimeService,
                                  provider: streamableProvider,
                                  trigger: trigger)

        let dataProvider = DataProvider(source: AnyDataProviderSource(source),
                                        repository: AnyDataProviderRepository(repository),
                                        updateTrigger: trigger)

        providers[localKey] = WeakWrapper(target: dataProvider)

        return dataProvider
    }
}
