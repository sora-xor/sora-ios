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
import CoreData
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils

protocol WalletContextFactoryProtocol: AnyObject {
    func createContext(connection: JSONRPCEngine,
                       assetManager: AssetManagerProtocol,
                       accountSettings: WalletAccountSettingsProtocol,
                       demeterFarmingService: DemeterFarmingServiceProtocol) throws -> CommonWalletContextProtocol
}

enum WalletContextFactoryError: Error {
    case missingEnpoint
    case requestSignerInitFailed
    case missingAccount
    case missingPriceAsset
    case missingConnection
}

final class WalletContextFactory {
    let keychain: KeystoreProtocol
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol
    let primitiveFactory: WalletPrimitiveFactoryProtocol
    private let selectedAccount: () -> AccountItem?
    private let runtimeProvider: () -> RuntimeProviderProtocol?
    private let substrateStorage: StorageFacadeProtocol?
    private let accountStorage: StorageFacadeProtocol?
    private let localizationManager: LocalizationManagerProtocol

    init(keychain: KeystoreProtocol = Keychain(),
         applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
         logger: LoggerProtocol = Logger.shared,
         selectedAccount: @escaping () -> AccountItem? = { SelectedWalletSettings.shared.currentAccount },
         runtimeProvider: @escaping () -> RuntimeProviderProtocol? = {
             ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
         },
         substrateStorage: StorageFacadeProtocol? = nil,
         accountStorage: StorageFacadeProtocol? = nil,
         localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) {
        self.keychain = keychain
        self.applicationConfig = applicationConfig
        self.logger = logger
        self.selectedAccount = selectedAccount
        self.runtimeProvider = runtimeProvider
        self.substrateStorage = substrateStorage
        self.accountStorage = accountStorage
        self.localizationManager = localizationManager

        primitiveFactory = WalletPrimitiveFactory(keystore: keychain)
    }

    private func subscribeContextToLanguageSwitch(_ context: CommonWalletContextProtocol,
                                                  localizationManager: LocalizationManagerProtocol,
                                                  logger: LoggerProtocol) {
        localizationManager.addObserver(with: context) { [weak context] (_, newLocalization) in
            if let newLanguage = WalletLanguage(rawValue: newLocalization) {
                do {
                    try context?.prepareLanguageSwitchCommand(with: newLanguage).execute()
                } catch {
                    logger.error("Error received when tried to change wallet language")
                }
            } else {
                logger.error("New selected language \(newLocalization) error is unsupported")
            }
        }
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    //swiftlint:disable:next function_body_length

    func createContext(connection: JSONRPCEngine,
                       assetManager: AssetManagerProtocol,
                       accountSettings: WalletAccountSettingsProtocol,
                       demeterFarmingService: DemeterFarmingServiceProtocol) throws -> CommonWalletContextProtocol {

        guard let selectedAccount = selectedAccount() else {
            throw WalletContextFactoryError.missingAccount
        }

        logger.debug("Loading selected wallet account")

        let networkType = selectedAccount.addressType

        let accountSigner = SigningWrapper(keystore: keychain, account: selectedAccount)
        let dummySigner = try DummySigner(cryptoType: selectedAccount.cryptoType)

        let substrateStorageFacade = substrateStorage ?? SubstrateDataStorageFacade.shared
        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()

        let localStorageIdFactory = try ChainStorageIdFactory(chain: Chain.sora)
        guard let runtime = runtimeProvider() else {
            throw WalletContextFactoryError.missingConnection
        }
        let extrinsicService = ExtrinsicService(address: selectedAccount.address,
                                                cryptoType: selectedAccount.cryptoType,
                                                runtimeRegistry: runtime,
                                                engine: connection,
                                                operationManager: OperationManagerFacade.sharedManager)

        let nodeOperationFactory = WalletNetworkOperationFactory(engine: connection,
                                                                 requestFactory: StorageRequestFactory(
                                                                    remoteFactory: StorageKeyFactory() as StorageKeyFactoryProtocol,
                                                                    operationManager: OperationManagerFacade.sharedManager
                                                                ),
                                                                 runtimeService: runtime,
                                                                 accountSettings: accountSettings,
                                                                 cryptoType: selectedAccount.cryptoType,
                                                                 accountSigner: accountSigner, extrinsicService: extrinsicService,
                                                                 dummySigner: dummySigner,
                                                                 chainStorage:
                                                                    AnyDataProviderRepository(chainStorage),
                                                                 localStorageIdFactory: localStorageIdFactory)

        let coingeckoOperationFactory = CoingeckoOperationFactory()

        let polkaswapNetworkOperationFactory = PolkaswapNetworkOperationFactory(engine: connection)

        let txFilter = NSPredicate.filterTransactionsBy(address: selectedAccount.address)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            substrateStorageFacade.createRepository(filter: txFilter)

        let contactOperationFactory = WalletContactOperationFactory(storageFacade: substrateStorageFacade,
                                                                    targetAddress: selectedAccount.address)

        let accountStorage: CoreDataRepository<AccountItem, CDAccountItem> =
            (self.accountStorage ?? UserDataStorageFacade.shared)
            .createRepository(filter: NSPredicate.filterAccountBy(networkType: networkType),
                              sortDescriptors: [NSSortDescriptor.accountsByOrder],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))

        let networkFacade = WalletNetworkFacade(accountSettings: accountSettings,
                                                nodeOperationFactory: nodeOperationFactory,
                                                coingeckoOperationFactory: coingeckoOperationFactory,
                                                polkaswapNetworkOperationFactory: polkaswapNetworkOperationFactory,
                                                chainStorage: AnyDataProviderRepository(chainStorage),
                                                localStorageIdFactory: localStorageIdFactory,
                                                txStorage: AnyDataProviderRepository(txStorage),
                                                contactsOperationFactory: contactOperationFactory,
                                                accountsRepository: AnyDataProviderRepository(accountStorage),
                                                address: selectedAccount.address,
                                                networkType: networkType, assetManager: assetManager,
                                                totalPriceAssetId: nil,
                                                runtimeService: runtime,
                                                requestFactory: StorageRequestFactory(
                                                    remoteFactory: StorageKeyFactory(),
                                                    operationManager: OperationManagerFacade.sharedManager
                                                ),
                                                engine: connection, 
                                                demeterFarmingService: demeterFarmingService)
                                                

        let builder = CommonWalletBuilder.builder(with: accountSettings,
                                                  networkOperationFactory: networkFacade)

        let context = try builder.with(localizationManager: localizationManager).build()

        subscribeContextToLanguageSwitch(context,
                                         localizationManager: localizationManager,
                                         logger: logger)

        return context
    }
}
