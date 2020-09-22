import Foundation

final class StartupPresenter {
	weak var view: StartupViewProtocol?
	var interactor: StartupInteractorInputProtocol!
	var wireframe: StartupWireframeProtocol!

    let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }
}

extension StartupPresenter: StartupPresenterProtocol {
    func setup() {
        interactor.verify()
    }
}

extension StartupPresenter: StartupInteractorOutputProtocol {
    func didDecideOnboarding() {
        wireframe.showOnboarding(from: view)
    }

    func didDecideMain() {
        wireframe.showMain(from: view)
    }

    func didDecidePincodeSetup() {
        wireframe.showPincodeSetup(from: view)
    }

    func didDecideUnsupportedVersion(data: SupportedVersionData) {
        wireframe.presentUnsupportedVersion(for: data, on: view?.controller.view.window, animated: true)
    }

    func didChangeState() {
        switch interactor.state {
        case .waitingRetry:
            view?.didUpdate(title: R.string.localizable
                .startupWaitingNetworkTitle(preferredLanguages: locale.rLanguages),
                            subtitle: R.string.localizable
                                .startupWaitingNetworkSubtitle(preferredLanguages: locale.rLanguages))
        default:
            view?.didUpdate(title: R.string.localizable
                .startupVerificationTitle(preferredLanguages: locale.rLanguages),
                            subtitle: R.string.localizable
                                .startupVerificationSubtitle(preferredLanguages: locale.rLanguages))
        }
    }
}
