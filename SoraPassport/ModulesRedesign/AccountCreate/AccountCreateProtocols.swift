import IrohaCrypto
import SoraFoundation
import SSFCloudStorage

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func activateInfo()
    func proceed()
    func share()
    func restoredApp()
    func skip()
    func backupToGoogle()
}

protocol AccountCreateInteractorInputProtocol: SignInGoogle {
    func setup()
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol)
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Swift.Error)
    func didReceive(words: [String], afterConfirmationFail: Bool)
    func didCompleteConfirmation(for account: AccountItem)
    func didReceive(error: Swift.Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting, Authorizable, Loadable {
    func proceed(on controller: UIViewController?)
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata)
    func setupBackupAccountPassword(on controller: AccountCreateViewProtocol?, account: OpenBackupAccount)
}

protocol Authorizable {
    func authorize()
}

extension Authorizable {
    func authorize() {}
}
