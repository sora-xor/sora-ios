import Foundation
import SoraKeystore
import SoraFoundation
import IrohaCrypto
import RobinHood

final class AccountConfirmViewFactory {
    static func createViewForOnboardingRedesign(request: AccountCreationRequest,
                                        metadata: AccountCreationMetadata) -> ControllerBackedProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }
        
        let viewModel = ConfirmPassphraseViewModel(mnemonic: metadata.mnemonic)
        
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AccountConfirmInteractor(request: request,
                                                  mnemonic: mnemonic,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(accountRepository),
                                                  settings: settings,
                                                  operationManager: OperationManagerFacade.sharedManager)
        viewModel.interactor = interactor
        viewModel.wireframe = ConfirmPassphraseyWireframe()
        interactor.presenter = viewModel

        let view = ConfirmPassphraseViewController(viewModel: viewModel)
        viewModel.view = view

        return view
    }
    
    static func createViewForRedesignAdding(request: AccountCreationRequest,
                                            metadata: AccountCreationMetadata,
                                            endAddingBlock: (() -> Void)?) -> ControllerBackedProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }

        let viewModel = ConfirmPassphraseViewModel(mnemonic: metadata.mnemonic)

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AddAccountConfirmInteractor(request: request,
                                                     mnemonic: mnemonic,
                                                     accountOperationFactory: accountOperationFactory,
                                                     accountRepository: AnyDataProviderRepository(accountRepository),
                                                     operationManager: OperationManagerFacade.sharedManager,
                                                     settings: SelectedWalletSettings.shared,
                                                     eventCenter: EventCenter.shared)
        let wireframe = ConfirmPassphraseyWireframe()

        viewModel.interactor = interactor
        viewModel.wireframe = wireframe
        interactor.presenter = viewModel
        wireframe.endAddingBlock = endAddingBlock

        
        let view = ConfirmPassphraseViewController(viewModel: viewModel)
        viewModel.view = view

        return view
    }
}
