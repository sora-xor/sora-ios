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
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        chainRegistry.subscribeToChians()
        chainRegistry.syncUp()
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
        #if !targetEnvironment(simulator)
        self.migrationService.checkMigration()
        #endif
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
