/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
    func updateOnNetworkChange()
    func checkMigration()
}

final class ServiceCoordinator {
    let eventCenter: EventCenterProtocol
    let subscriptionsFactory: WebSocketSubscriptionFactoryProtocol
    let migrationService: MigrationServiceProtocol
    private(set) var subscriptions: [WebSocketSubscribing]?

    init(eventCenter: EventCenterProtocol,
         subscriptionsFactory: WebSocketSubscriptionFactoryProtocol,
         migrationService: MigrationServiceProtocol) {
        self.eventCenter = eventCenter
        self.subscriptionsFactory = subscriptionsFactory
        self.migrationService = migrationService

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    private func setup(chainRegistry: ChainRegistryProtocol) {
        
        let semaphore = DispatchSemaphore(value: 0)

        chainRegistry.chainsSubscribe(self, runningInQueue: DispatchQueue.global()) { changes in
            if !changes.isEmpty {
                semaphore.signal()
            }
        }

        semaphore.wait()
    }

    private func updateWebSocketSettings() {
//        let connectionItem = settings.selectedConnection
//        let account = settings.selectedAccount
//
//        let settings = WebSocketServiceSettings(url: connectionItem.url,
//                                                addressType: connectionItem.type,
//                                                address: account?.address)
//        webSocketService.update(settings: settings)
    }

    private func updateRuntimeService() {
//        let connectionItem = settings.selectedConnection
//        runtimeService.update(to: connectionItem.type.chain, forced: false)
    }

    private func updateValidatorService() {
//        if let engine = webSocketService.connection {
//            let chain = settings.selectedConnection.type.chain
//            validatorService.update(to: chain, engine: engine)
//        }
    }

    private func updateRewardCalculatorService() {
//        let chain = settings.selectedConnection.type.chain
//        rewardCalculatorService.update(to: chain)
    }

    private func setupSubscriptions(connection: JSONRPCEngine?) {
        if let account = SelectedWalletSettings.shared.currentAccount, let engine = connection {
            let address = account.address
            let type = account.addressType
            subscriptions = try? subscriptionsFactory.createSubscriptions(address: address,
                                                                          type: type,
                                                                          engine: engine)
        } else {
            subscriptions = nil
        }
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        self.subscriptions = nil
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        self.setupSubscriptions(connection: chainRegistry.getConnection(for: Chain.sora.genesisHash()))
//        updateWebSocketSettings()
//        updateRuntimeService()
//        updateValidatorService()
//        updateRewardCalculatorService()
    }

    func updateOnNetworkChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
        updateRewardCalculatorService()
    }

    func setup() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        setup(chainRegistry: chainRegistry)

        self.setupSubscriptions(connection: chainRegistry.getConnection(for: Chain.sora.genesisHash()))
    }

    func throttle() {
        ChainRegistryFacade.sharedRegistry.chainsUnsubscribe(self)
    }

    func checkMigration() {
        self.migrationService.checkMigration()
    }
}

extension ServiceCoordinator: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        updateOnAccountChange()
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        updateOnAccountChange()
    }
}

extension ServiceCoordinator {

    static let shared = createDefault()

    private static func createDefault() -> ServiceCoordinatorProtocol {
        let subscriptionFactory = WebSocketSubscriptionFactory(storageFacade: SubstrateDataStorageFacade.shared)

        let migrationService = MigrationService(eventCenter: EventCenter.shared,
                                                keystore: Keychain(),
                                                settings: SettingsManager.shared,
                                                operationManager: OperationManagerFacade.sharedManager,
                                                logger: Logger.shared)

        return ServiceCoordinator(eventCenter: EventCenter.shared,
                                  subscriptionsFactory: subscriptionFactory,
                                  migrationService: migrationService)
    }
}
