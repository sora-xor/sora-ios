/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class StartupPresenter {
	weak var view: StartupViewProtocol?
	var interactor: StartupInteractorInputProtocol!
	var wireframe: StartupWireframeProtocol!
}

extension StartupPresenter: StartupPresenterProtocol {
    func viewIsReady() {
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
            view?.didUpdate(title: R.string.localizable.startupWaitingNetworkTitle(),
                            subtitle: R.string.localizable.startupWaitingNetworkSubtitle())
        default:
            view?.didUpdate(title: R.string.localizable.startupVerificationTitle(),
                            subtitle: R.string.localizable.startupVerificationSubtitle())
        }
    }
}
