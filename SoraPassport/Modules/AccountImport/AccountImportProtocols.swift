import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setDerivationPath(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)
}

protocol AccountImportPresenterProtocol: class {
    func setup()
    func proceed()
}

protocol AccountImportInteractorInputProtocol: class {
    func setup()
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest)
    func importAccountWithSeed(request: AccountImportSeedRequest)
    func importAccountWithKeystore(request: AccountImportKeystoreRequest)
    func deriveMetadataFromKeystore(_ keystore: String)
}

protocol AccountImportInteractorOutputProtocol: class {
    func didReceiveAccountImport(metadata: AccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountImportViewProtocol?)
}

protocol AccountImportViewFactoryProtocol: class {
	static func createViewForOnboarding() -> AccountImportViewProtocol?
}
