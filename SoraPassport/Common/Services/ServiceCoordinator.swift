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
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
    func updateOnNetworkChange()
    func checkMigration()
}

final class ServiceCoordinator {
    let eventCenter: EventCenterProtocol
    let subscriptionsFactory: WebSocketSubscriptionFactoryProtocol
    let migrationService: MigrationServiceProtocol
    private let network: StartupNetworkCoordinating
    private let chainRegistry: () -> ChainRegistryProtocol
    private(set) var subscriptions: [WebSocketSubscribing]?

    /// - Parameters:
    ///   - network: told when `setup` starts the chain registry.
    ///   - chainRegistry: the app's chain registry. It is created by its
    ///     first use, which has to be on the main thread.
    init(eventCenter: EventCenterProtocol,
         subscriptionsFactory: WebSocketSubscriptionFactoryProtocol,
         migrationService: MigrationServiceProtocol,
         network: StartupNetworkCoordinating = StartupNetworkCoordinator.shared,
         chainRegistry: @escaping () -> ChainRegistryProtocol = { ChainRegistryFacade.sharedRegistry }) {
        self.eventCenter = eventCenter
        self.subscriptionsFactory = subscriptionsFactory
        self.migrationService = migrationService
        self.network = network
        self.chainRegistry = chainRegistry

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    /// Starts the chain registry for the wallet that is being opened.
    ///
    /// Startup has usually booted the registry already, and this only syncs
    /// it again. A startup that ended at the 1.x upgrade screen has not: the
    /// wallet that opens after the upgrade is then the first to start it.
    /// The asset list and the remote node list are loaded in the background
    /// and reach the registry only once they are told that it has been
    /// started. They were told by startup alone, so a wallet opened after a
    /// 1.x upgrade never asked for its asset list and stayed empty until the
    /// app was closed. As in `SplashInteractor.bootChainRegistry`, the
    /// registry is created first (the caller is on the main thread), then
    /// the background work is told, then the registry is started.
    private func startChainRegistry() -> ChainRegistryProtocol {
        let registry = chainRegistry()
        network.chainRegistryWillBoot()
        registry.subscribeToChians()
        registry.syncUp()
        return registry
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

    @MainActor
    private func updateSora2PendingRecoveryReadiness() {
        let registry = chainRegistry()
        guard
            registry.getConnection(for: Chain.sora.genesisHash()) != nil,
            registry.getRuntimeProvider(for: Chain.sora.genesisHash()) != nil
        else {
            Sora2PendingSubmissionRecoveryRuntime.shared
                .markChainUnavailable()
            return
        }
        Sora2PendingSubmissionRecoveryRuntime.shared
            .markChainReadyAndResume()
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        self.subscriptions = nil
        let registry = chainRegistry()
        self.setupSubscriptions(connection: registry.getConnection(for: Chain.sora.genesisHash()))
        Task { @MainActor in
            self.updateSora2PendingRecoveryReadiness()
        }
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
        let registry = startChainRegistry()

        self.setupSubscriptions(connection: registry.getConnection(for: Chain.sora.genesisHash()))
        Task { @MainActor in
            self.updateSora2PendingRecoveryReadiness()
        }
    }

    func throttle() {
        chainRegistry().chainsUnsubscribe(self)
        Task { @MainActor in
            Sora2PendingSubmissionRecoveryRuntime.shared
                .markChainUnavailable()
        }
    }

    func checkMigration() {
        migrationService.checkMigration()
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
