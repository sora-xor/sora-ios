/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import SoraKeystore
import SoraFoundation
import RobinHood

protocol DataStreamServiceProtocol: UserApplicationServiceProtocol {
    var isSetup: Bool { get }
    var handler: DataStreamHandling { get }
}

final class DataStreamService {
    private var connection: DataStreamConnectionManager?

    let handler: DataStreamHandling

    init() {
        let handler = DataStreamHandler(streamProcessors: Self.createDefaultProcessors())
        handler.logger = Logger.shared
        self.handler = handler
    }

    init(processors: [DataStreamProcessing]) {
        let handler = DataStreamHandler(streamProcessors: processors)
        handler.logger = Logger.shared
        self.handler = handler
    }
}

extension DataStreamService {
    static func createDefaultProcessors() -> [DataStreamProcessing] {
        var processors = [DataStreamProcessing]()

        if let withdrawProcessor = createWithdrawProcessor() {
            processors.append(withdrawProcessor)
        }

        if let depositProcessor = createDepositProcessor() {
            processors.append(depositProcessor)
        }

        if let ethRegistrationProcessor = creatEthereumRegistrationProcessor() {
            processors.append(ethRegistrationProcessor)
        }

        if let soranetTransferProcessor = createSoranetTransferProcessor() {
            processors.append(soranetTransferProcessor)
        }

        return processors
    }

    static func createWithdrawProcessor() -> DataStreamProcessing? {
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.transfer
        let repository: CoreDataRepository<WithdrawOperationData, CDWithdraw> =
            UserStoreFacade.shared.createCoreDataCache()

        return WithdrawDataStreamProcessor(repository: AnyDataProviderRepository(repository),
                                           operationManager: operationManager,
                                           logger: logger)
    }

    static func createDepositProcessor() -> DataStreamProcessing? {
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.transfer

        let repository: CoreDataRepository<DepositOperationData, CDDeposit> =
        UserStoreFacade.shared.createCoreDataCache()

        return DepositDataStreamProcessor(depositRepository: AnyDataProviderRepository(repository),
                                          operationManager: operationManager,
                                          logger: logger)
    }

    static func creatEthereumRegistrationProcessor() -> DataStreamProcessing? {
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.transfer

        let mapper = SidechainInitDataMapper<EthereumInitUserInfo>()
        let repository: CoreDataRepository<EthereumInit, CDSidechainInit> =
            UserStoreFacade.shared.createCoreDataCache(mapper: AnyCoreDataMapper(mapper))

        return EthereumRegistrationStreamProcessor(repository: AnyDataProviderRepository(repository),
                                                   operationManager: operationManager,
                                                   logger: logger)
    }

    static func createSoranetTransferProcessor() -> DataStreamProcessing? {
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.transfer

        let filter = NSPredicate(format: "%K == %@", #keyPath(CDDeposit.status),
                                 DepositOperationData.Status.transferPending.rawValue)
        let repository: CoreDataRepository<DepositOperationData, CDDeposit> =
            UserStoreFacade.shared.createCoreDataCache(filter: filter)

        return SoranetTransferProcessor(repository: AnyDataProviderRepository(repository),
                                        operationManager: operationManager,
                                        logger: logger)
    }
}

extension DataStreamService: DataStreamServiceProtocol {
    var isSetup: Bool {
        connection != nil
    }

    func setup() {
        guard connection == nil else {
            return
        }

        guard let reachabilityManager = ReachabilityManager.shared else {
            return
        }

        let logger = Logger.shared

        guard let requestSigner = DARequestSigner.createDefault(with: logger) else {
            return
        }

        do {
            connection = try DataStreamConnectionManager(eventHandler: handler,
                                                         serviceUnit: ApplicationConfig.shared.defaultStreamUnit,
                                                         settings: SettingsManager.shared,
                                                         applicationListener: ApplicationHandler(),
                                                         networkStatusListener: reachabilityManager,
                                                         requestSigner: requestSigner,
                                                         logger: logger)
        } catch {
            logger.error("Did receive stream connection error error: \(error)")
        }
    }

    func throttle() {
        connection = nil
    }
}
