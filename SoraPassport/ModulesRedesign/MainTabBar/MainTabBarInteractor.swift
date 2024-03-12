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
import SSFUtils

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol
    let keystoreImportService: KeystoreImportServiceProtocol

    init(eventCenter: EventCenterProtocol,
         serviceCoordinator: ServiceCoordinatorProtocol,
         keystoreImportService: KeystoreImportServiceProtocol) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator
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
