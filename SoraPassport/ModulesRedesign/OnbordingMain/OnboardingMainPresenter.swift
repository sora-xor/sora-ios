import Foundation
import SSFCloudStorage

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var interactor: OnboardingMainInteractorInputProtocol!
    var wireframe: OnboardingMainWireframeProtocol!

    let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }
    
    private func showScreenAfterSelection(_ result: (Result<[OpenBackupAccount], Error>)) {
        wireframe.hideActivityIndicator()
        switch result {
        case .success(let accounts):
            if accounts.isEmpty {
                wireframe.showSignup(from: view)
                return
            }
            wireframe.showBackupedAccounts(from: view, accounts: accounts)
        case .failure:
            break
        }
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {

    func setup() {
        interactor.setup()
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        showActionSheet()
    }
    
    func activateCloudStorageConnection() {
        wireframe?.showActivityIndicator()
        interactor.getBackupedAccounts(completion: showScreenAfterSelection)
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestKeystoreImport() {
        wireframe.showKeystoreImport(from: view)
    }
}

private extension OnboardingMainPresenter {
    func showActionSheet() {
        let title = R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale)
        let message = R.string.localizable.importAccountMessage(preferredLanguages: .currentLocale)
        let closeActionText = R.string.localizable.commonCancel(preferredLanguages: .currentLocale)
        let rawSeedText = R.string.localizable.commonRawSeed(preferredLanguages: .currentLocale)
        let passphraseText = R.string.localizable.recoveryPassphrase(preferredLanguages: .currentLocale)
        
        let googleAction = AlertPresentableAction(title: "Google") { [weak self] in
            guard let self = self else { return }
            self.activateCloudStorageConnection()
        }
        
        let passphraseAction = AlertPresentableAction(title: passphraseText) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestoreRedesign(from: self.view, sourceType: .mnemonic)
        }
        
        let rawSeedAction = AlertPresentableAction(title: rawSeedText) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestoreRedesign(from: self.view, sourceType: .seed)
        }

        let viewModel = AlertPresentableViewModel(title: title,
                                                  message: message,
                                                  actions: [googleAction, passphraseAction, rawSeedAction],
                                                  closeAction: closeActionText)
        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
