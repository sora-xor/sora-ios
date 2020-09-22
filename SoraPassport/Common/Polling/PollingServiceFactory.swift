/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

struct PollingServiceFactory {

    private func createEthereumTransferPoll() -> EthereumTransferPoll? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let keychain = Keychain()
            let operationManager = OperationManagerFacade.transfer

            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<TransferOperationData, CDTransfer>
                = UserStoreFacade.shared.createCoreDataCache()

            let contextObservable = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                              mapper: repository.dataMapper,
                                                              predicate: { _ in true })

            let ethereumOperationFactory = try EthereumOperationFactory(node: config.ethereumNodeUrl,
                                                                        keystore: keychain,
                                                                        chain: config.ethereumChainId)

            contextObservable.start { error in
                if let error = error {
                    logger.error("Can't start context observable: \(error)")
                }
            }

            return EthereumTransferPoll(operationFactory: ethereumOperationFactory,
                                        repository: AnyDataProviderRepository(repository),
                                        repositoryObservable: contextObservable,
                                        operationManager: operationManager,
                                        logger: logger)
        } catch {
            logger.error("Can't create ethereum transfer poll: \(error)")
            return nil
        }
    }

    private func createWithdrawConfirmationPoll() -> EthereumWithdrawConfirmationPoll? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let keychain = Keychain()
            let operationManager = OperationManagerFacade.transfer

            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<WithdrawOperationData, CDWithdraw>
                = UserStoreFacade.shared.createCoreDataCache()

            let contextObservable = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                              mapper: repository.dataMapper,
                                                              predicate: { _ in true })

            let ethereumOperationFactory = try EthereumOperationFactory(node: config.ethereumNodeUrl,
                                                                        keystore: keychain,
                                                                        chain: config.ethereumChainId)

            contextObservable.start { error in
                if let error = error {
                    logger.error("Can't start context observable: \(error)")
                }
            }

            return EthereumWithdrawConfirmationPoll(operationFactory: ethereumOperationFactory,
                                                    repository: AnyDataProviderRepository(repository),
                                                    repositoryObservable: contextObservable,
                                                    operationManager: operationManager,
                                                    logger: logger)
        } catch {
            logger.error("Can't create ethereum withdraw confirmation poll: \(error)")
            return nil
        }
    }

    private func createDepositPoll() -> EthereumDepositPoll? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let keychain = Keychain()
            let operationManager = OperationManagerFacade.transfer

            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<DepositOperationData, CDDeposit>
                = UserStoreFacade.shared.createCoreDataCache()

            let contextObservable = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                              mapper: repository.dataMapper,
                                                              predicate: { _ in true })

            let ethereumOperationFactory = try EthereumOperationFactory(node: config.ethereumNodeUrl,
                                                                        keystore: keychain,
                                                                        chain: config.ethereumChainId)

            contextObservable.start { error in
                if let error = error {
                    logger.error("Can't start context observable: \(error)")
                }
            }

            return EthereumDepositPoll(operationFactory: ethereumOperationFactory,
                                       repository: AnyDataProviderRepository(repository),
                                       repositoryObservable: contextObservable,
                                       operationManager: operationManager,
                                       logger: logger)
        } catch {
            logger.error("Can't create ethereum deposit poll: \(error)")
            return nil
        }
    }

    private func createWithdrawTransferPoll() -> EthereumWithdrawTransferPoll? {
        let logger = Logger.shared

        do {
            let config: ApplicationConfigProtocol = ApplicationConfig.shared
            let keychain = Keychain()
            let operationManager = OperationManagerFacade.transfer

            let userStoreFacade = UserStoreFacade.shared
            let repository: CoreDataRepository<WithdrawOperationData, CDWithdraw>
                = UserStoreFacade.shared.createCoreDataCache()

            let contextObservable = CoreDataContextObservable(service: userStoreFacade.databaseService,
                                                              mapper: repository.dataMapper,
                                                              predicate: { _ in true })

            let ethereumOperationFactory = try EthereumOperationFactory(node: config.ethereumNodeUrl,
                                                                        keystore: keychain,
                                                                        chain: config.ethereumChainId)

            contextObservable.start { error in
                if let error = error {
                    logger.error("Can't start context observable: \(error)")
                }
            }

            return EthereumWithdrawTransferPoll(operationFactory: ethereumOperationFactory,
                                                repository: AnyDataProviderRepository(repository),
                                                repositoryObservable: contextObservable,
                                                operationManager: operationManager,
                                                logger: logger)
        } catch {
            logger.error("Can't create ethereum deposit poll: \(error)")
            return nil
        }
    }
}

extension PollingServiceFactory: UserApplicationServiceFactoryProtocol {
    func createServices() -> [UserApplicationServiceProtocol] {
        var pollables: [Pollable] = []

        if let transferPoll = createEthereumTransferPoll() {
            pollables.append(transferPoll)
        }

        if let withdrawConfirmationPoll = createWithdrawConfirmationPoll() {
            pollables.append(withdrawConfirmationPoll)
        }

        if let depositPoll = createDepositPoll() {
            pollables.append(depositPoll)
        }

        if let withdrawTransferPoll = createWithdrawTransferPoll() {
            pollables.append(withdrawTransferPoll)
        }

        let pollingInterval = ApplicationConfig.shared.ethereumPollingTimeInterval

        let pollingService = PollingService(pollables: pollables,
                                            pollingInterval: pollingInterval,
                                            applicationHandler: ApplicationHandler(),
                                            logger: Logger.shared)

        return [pollingService]
    }
}
