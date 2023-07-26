import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import IrohaCrypto

final class SetupPasswordViewFactory {
    static func createView(with account: OpenBackupAccount,
                           createAccountRequest: AccountCreationRequest? = nil,
                           createAccountService: CreateAccountServiceProtocol? = nil,
                           mnemonic: IRMnemonicProtocol? = nil,
                           entryPoint: EntryPoint,
                           completion: (() -> Void)? = nil) -> SetupPasswordViewProtocol? {
        let view = SetupPasswordViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        let viewModel = SetupPasswordPresenter(account: account,
                                               cloudStorageService: cloudStorageService,
                                               createAccountRequest: createAccountRequest,
                                               createAccountService: createAccountService,
                                               mnemonic: mnemonic,
                                               entryPoint: entryPoint,
                                               keystore: Keychain(),
                                               completion: completion)
        let wireframe = SetupPasswordWireframe(currentController: view)
        view.viewModel = viewModel
        viewModel.view = view
        viewModel.wireframe = wireframe
        return view
    }
}
