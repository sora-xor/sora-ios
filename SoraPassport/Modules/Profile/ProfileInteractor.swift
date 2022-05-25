import Foundation
import RobinHood
import SoraKeystore

final class ProfileInteractor {
	weak var presenter: ProfileInteractorOutputProtocol?

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var cacheFacade: CoreDataCacheFacadeProtocol
    private(set) var userDataFacade: StorageFacadeProtocol
    private(set) var substrateDataFacade: StorageFacadeProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         cacheFacade: CoreDataCacheFacadeProtocol,
         substrateDataFacade: StorageFacadeProtocol,
         userDataFacade: StorageFacadeProtocol) {

        self.keystore = keystore
        self.settings = settings
        self.cacheFacade = cacheFacade
        self.substrateDataFacade = substrateDataFacade
        self.userDataFacade = userDataFacade
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {

    func logoutAndClean() {
        cleanKeystore()
        cleanSettings()
        cleanCoreData()
        stopServices()
        // TODO: [SN-377] Clean Capital cache
        presenter?.restart()
    }
}

private extension ProfileInteractor {

    func cleanKeystore() {
        try? keystore.deleteAll()
    }

    func stopServices() {
        WebSocketService.shared.throttle()
        RuntimeRegistryFacade.sharedService.throttle()
    }

    func cleanSettings() {
        settings.removeAll()
    }

    func cleanCoreData() {
        try? cacheFacade.databaseService.close()
        try? cacheFacade.databaseService.drop()

        try? substrateDataFacade.databaseService.close()
        try? substrateDataFacade.databaseService.drop()

        try? userDataFacade.databaseService.close()
        try? userDataFacade.databaseService.drop()
    }
}
