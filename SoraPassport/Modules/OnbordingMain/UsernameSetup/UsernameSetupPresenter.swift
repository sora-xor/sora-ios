import Foundation
import SoraFoundation
import SoraKeystore

final class UsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var viewModel: InputViewModel!
    let settingsManager = SettingsManager.shared
    var userName: String? {
        get { settingsManager.userName }
        set {
            let newUserName = newValue ?? ""
            settingsManager.selectedAccount = settingsManager.selectedAccount?.replacingUsername(newUserName)
        }
    }
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        let inputHandling = InputHandler(value: userName ?? "",
                                         required: false,
                                         predicate: NSPredicate.notEmpty,
                                         processor: ByteLengthProcessor.username)
        viewModel = InputViewModel(inputHandler: inputHandling)
        view?.set(viewModel: viewModel)
    }

    func proceed() {
        let value = viewModel.inputHandler.value

        let rLanguages = localizationManager?.selectedLocale.rLanguages
        let actionTitle = R.string.localizable.commonOk(preferredLanguages: rLanguages)
        let action = AlertPresentableAction(title: actionTitle) { [weak self] in
            self?.wireframe.proceed(from: self?.view, username: value)
        }

        let title = R.string.localizable.screenshotAlertTitle(preferredLanguages: rLanguages)
        let message = R.string.localizable.screenshotAlertText(preferredLanguages: rLanguages)
        let viewModel = AlertPresentableViewModel(title: title,
                                                  message: message,
                                                  actions: [action],
                                                  closeAction: nil)
        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    func activateURL(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url,
                              from: view,
                              style: .modal)
        }
    }
}

extension UsernameSetupPresenter: Localizable {
    func applyLocalization() {}
}
