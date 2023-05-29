import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setDerivationPath(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)
    func dissmissPresentedController()
    func resetFocus()
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func activateURL(_ url: URL)
}

protocol AccountImportInteractorInputProtocol: AnyObject {
    func setup()
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest)
    func importAccountWithSeed(request: AccountImportSeedRequest)
    func importAccountWithKeystore(request: AccountImportKeystoreRequest)
    func deriveMetadataFromKeystore(_ keystore: String)
}

protocol AccountImportInteractorOutputProtocol: AnyObject {
    func didReceiveAccountImport(metadata: AccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Swift.Error)
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable {
    func proceed(from view: AccountImportViewProtocol?)
}
