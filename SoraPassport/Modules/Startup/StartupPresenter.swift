/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
    func didGetError(_ error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = self.wireframe.present(error: error, from: nil, locale: Locale.current)
        }
    }

    func didDecideOnboarding() {
        wireframe.showOnboarding(from: view)
    }

    func didDecideMain() {
        DispatchQueue.main.async {
            self.wireframe.showMain(from: self.view)
        }
    }

    func didDecidePincodeSetup() {
        wireframe.showPincodeSetup(from: view)
    }

    func didDecideUnsupportedVersion(data: SupportedVersionData) {
        wireframe.presentUnsupportedVersion(for: data, on: view?.controller.view.window, animated: true)
    }

    func didReceiveConfigError(_ error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { //easiest way to overcome rootAnimator magic
           _ =  self.wireframe.present(error: error, from: nil, locale: self.locale)
        }
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
