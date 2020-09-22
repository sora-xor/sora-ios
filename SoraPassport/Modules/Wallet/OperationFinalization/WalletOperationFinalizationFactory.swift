/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraKeystore
import SoraFoundation

struct WalletOperationFinalizationFactory {
    private func createWithdrawTransferFinalizationService() -> WithdrawTransferFinalizationService? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let operationManager: OperationManagerProtocol = OperationManagerFacade.transfer
            let keychain = Keychain()
            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<WithdrawOperationData, CDWithdraw> =
                userStoreFacade.createCoreDataCache()
            let automaticHandlingDelay = config.combinedTransfersHandlingDelay

            let repositoryObserver = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                               mapper: repository.dataMapper,
                                                               predicate: { _ in true })

            let ethereumOperationFactory = try EthereumOperationFactory(node: config.ethereumNodeUrl,
                                                                        keystore: keychain,
                                                                        chain: config.ethereumChainId)

            repositoryObserver.start { error in
                if let error = error {
                    logger.error("Can't start context observer: \(error)")
                }
            }

            return WithdrawTransferFinalizationService(ethereumOperationFactory: ethereumOperationFactory,
                                                       repository: AnyDataProviderRepository(repository),
                                                       repositoryObserver: repositoryObserver,
                                                       operationManager: operationManager,
                                                       masterContract: config.ethereumMasterContract,
                                                       automaticHandlingDelay: automaticHandlingDelay,
                                                       logger: logger)
        } catch {
            logger.error("Can't create withdraw transfer finalization service: \(error)")
            return nil
        }
    }

    private func createWithdrawProofFinalizationService() -> WithdrawProofsFinalizationService? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let operationManager: OperationManagerProtocol = OperationManagerFacade.transfer
            let keychain = Keychain()

            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<WithdrawOperationData, CDWithdraw> =
                userStoreFacade.createCoreDataCache()
            let automaticHandlingDelay = config.combinedTransfersHandlingDelay

            let repositoryObserver = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                               mapper: repository.dataMapper,
                                                               predicate: { _ in true })

            let soranetOperationFactory = SoranetUnitOperationFactory()

            let ethereumOperationFactory = try EthereumOperationFactory(node: config.ethereumNodeUrl,
                                                                        keystore: keychain,
                                                                        chain: config.ethereumChainId)

            repositoryObserver.start { error in
                if let error = error {
                    logger.error("Can't start context observer: \(error)")
                }
            }

            let accountId = try WalletPrimitiveFactory(keychain: keychain,
                                                       settings: SettingsManager.shared,
                                                       localizationManager: LocalizationManager.shared)
                .createAccountId()

            return WithdrawProofsFinalizationService(accountId: accountId,
                                                     ethereumOperationFactory: ethereumOperationFactory,
                                                     soranetOperationFactory: soranetOperationFactory,
                                                     soranetUnit: config.defaultSoranetUnit,
                                                     repository: AnyDataProviderRepository(repository),
                                                     repositoryObserver: repositoryObserver,
                                                     operationManager: operationManager,
                                                     masterContract: config.ethereumMasterContract,
                                                     automaticHandlingDelay: automaticHandlingDelay,
                                                     logger: logger)
        } catch {
            logger.error("Can't create withdraw proof finalization service: \(error)")
            return nil
        }
    }

    private func createDepositFinalizationService() -> DepositFinalizationService? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let operationManager: OperationManagerProtocol = OperationManagerFacade.transfer
            let keychain = Keychain()

            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<DepositOperationData, CDDeposit> =
                userStoreFacade.createCoreDataCache()
            let automaticHandlingDelay = config.combinedTransfersHandlingDelay

            let primitiveFactory = WalletPrimitiveFactory(keychain: keychain,
                                                          settings: SettingsManager.shared,
                                                          localizationManager: LocalizationManager.shared)

            let networkResolver = try WalletContextFactory.createNetworkResolver(with: logger)

            let accountId = try primitiveFactory.createAccountId()
            let accountSettings = try primitiveFactory.createAccountSettings(for: accountId)
            let operationSettings = try primitiveFactory.createOperationSettings()

            let walletOperationFactory = SoraNetworkOperationFactory(accountSettings: accountSettings,
                                                                     operationSettings: operationSettings,
                                                                     networkResolver: networkResolver)

            let repositoryObserver = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                               mapper: repository.dataMapper,
                                                               predicate: { _ in true })

            repositoryObserver.start { error in
                if let error = error {
                    logger.error("Can't start context observer: \(error)")
                }
            }

            return DepositFinalizationService(walletOperationFactory: walletOperationFactory,
                                              repository: AnyDataProviderRepository(repository),
                                              observer: repositoryObserver,
                                              operationManager: operationManager,
                                              automaticHandlingDelay: automaticHandlingDelay,
                                              logger: logger)
        } catch {
            logger.error("Can't create deposit finalization service: \(error)")
            return nil
        }
    }
}

extension WalletOperationFinalizationFactory: UserApplicationServiceFactoryProtocol {
    func createServices() -> [UserApplicationServiceProtocol] {
        var services: [UserApplicationServiceProtocol] = []

        if let withdrawProofsFinalizattion = createWithdrawProofFinalizationService() {
            services.append(withdrawProofsFinalizattion)
        }

        if let depositFinalization = createDepositFinalizationService() {
            services.append(depositFinalization)
        }

        if let withdrawTransferFinalization = createWithdrawTransferFinalizationService() {
            services.append(withdrawTransferFinalization)
        }

        return services
    }
}
