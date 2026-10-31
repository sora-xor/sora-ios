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
import SSFUtils

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    /// Wallets made from a 3-, 6- or 9-word phrase that were never warned. Runs on a background queue.
    let unwarnedShortPhraseWallets: () -> [AccountItem]

    init(eventCenter: EventCenterProtocol,
         serviceCoordinator: ServiceCoordinatorProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         unwarnedShortPhraseWallets: @escaping () -> [AccountItem] = WalletShortPhraseWarning.unwarnedWalletsOnThisPhone) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator
        self.unwarnedShortPhraseWallets = unwarnedShortPhraseWallets
        serviceCoordinator.setup()
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func configureNotifications() {

    }

    func configureDeepLink() {

    }

    func searchPendingDeepLink() {

    }

    func resolvePendingDeepLink() {

    }

    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didRequestImportAccount()
        }
        serviceCoordinator.checkMigration()

        // The tab bar listens from here on (it has appeared). The wallet's
        // first asset list can have arrived after the tabs were built and
        // before this: its one event was then posted to nobody.
        presenter?.didReceiveWalletAssetList()

        // Wallets kept from App Store 3.8.6 with a 3-, 6- or 9-word phrase were
        // never warned when they were restored. Each launch warns those still unwarned.
        let findWallets = unwarnedShortPhraseWallets
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let wallets = findWallets()
            guard !wallets.isEmpty else { return }
            DispatchQueue.main.async { self?.presenter?.didFindUnwarnedShortPhraseWallets(wallets) }
        }
    }
}

extension MainTabBarInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        guard keystoreImportService.definition != nil else {
            return
        }

        presenter?.didRequestImportAccount()
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
//    func processPushNotification(event: PushNotificationEvent) {
//        updateWalletAccount()
//    }

    func processMigration(event: MigrationEvent) {
        presenter?.didRequestMigration(with: event.service)
    }

    func processSuccsessMigration(event: MigrationSuccsessEvent) {
        presenter?.didEndMigration()
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        presenter?.didReloadSelectedNetwork()
    }

    func processWalletAssetListArrived(event _: WalletAssetListArrived) {
        // Every tab was built from an empty asset list. They are all built
        // again, as for another account (one graph from one list), once that
        // takes no screen away from the user.
        presenter?.didReceiveWalletAssetList()
    }

    func processWalletUpdate(event: WalletUpdateEvent) {
//        updateWalletAccount()
    }
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        presenter?.didUserChange()
    }

    func processBalanceChanged(event: WalletBalanceChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processStakingChanged(event: WalletStakingInfoChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processNewTransaction(event: WalletNewTransactionInserted) {
        presenter?.didUpdateWalletInfo()
        presenter?.didEndTransaction()
    }
    
    func processLanguageChanged(event: LanguageChanged) {
        presenter?.didLanguageChange()
    }
}

extension MainTabBarInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification: Notification) {
//        updateWalletAccount()
        presenter?.didUpdateWalletInfo()
    }
}
