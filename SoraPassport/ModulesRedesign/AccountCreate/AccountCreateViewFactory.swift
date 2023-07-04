import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFCloudStorage

final class AccountCreateViewFactory {
    static func createViewForCreateAccount(username: String, endAddingBlock: (() -> Void)?) -> AccountCreateViewProtocol? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        
        let view = AccountCreateViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        view.mode = cloudStorageService.isUserAuthorized ? .registration : .registrationWithoutAccessToGoogle
        let presenter = AccountCreatePresenter(username: username)
        
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: Chain.sora,
                                                 accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 settings: settings,
                                                 eventCenter: EventCenter.shared,
                                                 cloudStorageService: cloudStorageService)
        
        let wireframe = AccountCreateWireframe()
        wireframe.endAddingBlock = endAddingBlock
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        
        return view
    }

    static func createViewForShowPassthrase(_ account: AccountItem) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController()
        view.mode = .view
        let presenter = AccountCreatePresenter(username: account.username)
        
        let interactor = AccountBackupInteractor(keystore: Keychain(),
                                                 mnemonicCreator: IRMnemonicCreator(language: .english),
                                                 account: account)
        let wireframe = AccountCreateWireframe()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        
        return view
    }
    
    static func createViewForImportAccount(
        username: String,
        isGoogleBackupSelected: Bool = false,
        endAddingBlock: (() -> Void)?
    ) -> AccountCreateViewProtocol? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared
        
        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
        UserDataStorageFacade.shared.createRepository()
        
        let view = AccountCreateViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        view.mode = isGoogleBackupSelected ? .registration : .registrationWithoutAccessToGoogle
        let presenter = AccountCreatePresenter(username: username, shouldCreatedWithGoogle: isGoogleBackupSelected)
        
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: Chain.sora,
                                                 accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 settings: settings,
                                                 eventCenter: EventCenter.shared,
                                                 cloudStorageService: cloudStorageService)
        
        let wireframe = AddCreationWireframe()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        wireframe.endAddingBlock = endAddingBlock
        
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        
        return view
    }
}
