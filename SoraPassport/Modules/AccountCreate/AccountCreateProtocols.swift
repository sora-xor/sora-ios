import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
}

protocol AccountCreatePresenterProtocol: class {
    func setup()
    func activateInfo()
    func proceed()
    func share()
}

protocol AccountCreateInteractorInputProtocol: class {
    func setup()
}

protocol AccountCreateInteractorOutputProtocol: class {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata)

}

protocol AccountCreateViewFactoryProtocol: class {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol?
    static func createViewForAdding(username: String) -> AccountCreateViewProtocol?
//    static func createViewForConnection(item: ConnectionItem, username: String) -> AccountCreateViewProtocol?
}
