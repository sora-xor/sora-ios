import Foundation
import SoraFoundation

final class UsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!

    private var viewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(predicate: NSPredicate.notEmpty,
                                         processor: ByteLengthProcessor.username)
        return InputViewModel(inputHandler: inputHandling)
    }()
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func setup() {
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
