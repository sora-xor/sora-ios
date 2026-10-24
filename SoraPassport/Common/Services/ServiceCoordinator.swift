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
