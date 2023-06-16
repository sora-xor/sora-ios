import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import FearlessUtils
import RobinHood

final class EnterPasswordViewFactory {
    static func createView(
        with selectedAddress: String,
        backedUpAccounts: [OpenBackupAccount],
        endAddingBlock: (() -> Void)? = nil
    ) -> EnterPasswordViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()
        
        let view = EnterPasswordViewController()
        let cloudStorage = CloudStorageService(uiDelegate: view)
        
        let interactor = AccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: OperationManagerFacade.sharedManager,
                                                 settings: settings,
                                                 keystoreImportService: keystoreImportService,
                                                 eventCenter: EventCenter.shared,
                                                 cloudStorage: cloudStorage)

        let wireframe = EnterPasswordWireframe(currentController: view, endAddingBlock: endAddingBlock)
        let viewModel = EnterPasswordViewModel(selectedAddress: selectedAddress,
                                               backedUpAccounts: backedUpAccounts,
                                               interactor: interactor,
                                               wireframe: wireframe)
        interactor.presenter = viewModel
        view.viewModel = viewModel

        return view
    }
}
