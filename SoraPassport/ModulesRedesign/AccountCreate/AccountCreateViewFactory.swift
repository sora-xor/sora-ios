import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore
import RobinHood

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        
        let view = AccountCreateViewController()
        let presenter = AccountCreatePresenter(username: username)
        
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: Chain.sora,
                                                 accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 settings: settings,
                                                 eventCenter: EventCenter.shared)
        
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

    static func createViewForBackup(_ account: AccountItem) -> AccountCreateViewProtocol? {
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
    
    static func createViewForAdding(username: String, endAddingBlock: (() -> Void)?) -> AccountCreateViewProtocol? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared
        
        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
        UserDataStorageFacade.shared.createRepository()
        
        let view = AccountCreateViewController()
        let presenter = AccountCreatePresenter(username: username)
        
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: Chain.sora,
                                                 accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 settings: settings,
                                                 eventCenter: EventCenter.shared)
        
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
