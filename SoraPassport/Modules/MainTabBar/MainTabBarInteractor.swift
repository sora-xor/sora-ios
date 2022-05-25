import Foundation
import SoraKeystore
import CommonWallet
import SoraFoundation
import FearlessUtils

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let settings: SettingsManagerProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol
    let keystoreImportService: KeystoreImportServiceProtocol

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    init(eventCenter: EventCenterProtocol,
         settings: SettingsManagerProtocol,
         serviceCoordinator: ServiceCoordinatorProtocol,
         keystoreImportService: KeystoreImportServiceProtocol) {
        self.eventCenter = eventCenter
        self.settings = settings
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator

        updateSelectedItems()

        startServices()
    }

    private func updateSelectedItems() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection
    }

    private func startServices() {
        serviceCoordinator.setup()
    }

    private func stopServices() {
        serviceCoordinator.throttle()
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

    func processWalletUpdate(event: WalletUpdateEvent) {
//        updateWalletAccount()
    }
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
//        if currentAccount != settings.selectedAccount {
//            updateWebSocketSettings()
//            updateSelectedItems()
//            presenter?.didReloadSelectedAccount()
//        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
//        if currentConnection != settings.selectedConnection {
//            updateWebSocketSettings()
//            updateSelectedItems()
//            presenter?.didReloadSelectedNetwork()
//        }
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
