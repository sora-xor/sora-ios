import UIKit
import IrohaCrypto
import SoraFoundation

enum AccountCreateContext: String {
    case cryptoType
    case networkType
}

final class AccountCreatePresenter: SharingPresentable {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    let username: String

    private var metadata: AccountCreationMetadata?

    private var selectedCryptoType: CryptoType?
    private var selectedNetworkType: Chain?

    private var derivationPathViewModel: InputViewModelProtocol?

    init(username: String) {
        self.username = username
    }

    private func applyDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            predicate = NSPredicate.deriviationPathHardSoftPassword
            placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
        } else {
            predicate = NSPredicate.deriviationPathHardPassword
            placeholder = DerivationPathConstants.hardPasswordPlaceholder
        }

        let inputHandling = InputHandler(predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        self.derivationPathViewModel = viewModel
    }

    private func presentDerivationPathError(_ cryptoType: CryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch cryptoType {
        case .sr25519:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationHardSoftPassword,
                                  from: view,
                                  locale: locale)
        case .ed25519, .ecdsa:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationHardPassword,
                                  from: view,
                                  locale: locale)
        }
    }
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {

    func setup() {
        interactor.setup()
    }

    func activateInfo() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let message = R.string.localizable.mnemonicAlertText(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonInfo(preferredLanguages: locale.rLanguages)
        wireframe.present(message: message,
                          title: title,
                          closeAction: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages),
                          from: view)
    }

    func share() {
        guard let phrase = metadata?.mnemonic.joined(separator: " ") else { return }
        let source = TextSharingSource(message: phrase)
        share(source: source,
              from: view,
              with: nil)
    }

    func proceed() {
        guard
            let networkType = selectedNetworkType,
            let cryptoType = selectedCryptoType,
            let viewModel = derivationPathViewModel,
            let metadata = metadata else {
            return
        }

        guard viewModel.inputHandler.completed else {
            presentDerivationPathError(cryptoType)
            return
        }

        let request = AccountCreationRequest(username: username,
                                             type: networkType,
                                             derivationPath: viewModel.inputHandler.value,
                                             cryptoType: cryptoType)

        wireframe.confirm(from: view,
                          request: request,
                          metadata: metadata)
    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: AccountCreationMetadata) {
        self.metadata = metadata

        selectedCryptoType = metadata.defaultCryptoType
        selectedNetworkType = metadata.defaultNetwork

        view?.set(mnemonic: metadata.mnemonic)

        applyDerivationPathViewModel()
    }

    func didReceiveMnemonicGeneration(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale)
    }
}

extension AccountCreatePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {

        }
    }
}
