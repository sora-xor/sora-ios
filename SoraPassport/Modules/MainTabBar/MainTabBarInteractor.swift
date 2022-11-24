/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import CommonWallet
import SoraFoundation
import FearlessUtils

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
}

extension MainTabBarInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification: Notification) {
//        updateWalletAccount()
        presenter?.didUpdateWalletInfo()
    }
}
