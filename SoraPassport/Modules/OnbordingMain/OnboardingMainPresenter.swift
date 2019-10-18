/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var interactor: OnboardingMainInputInteractorProtocol!
    var wireframe: OnboardingMainWireframeProtocol!

    var legalData: LegalData

    private func provideTutorialViewModels() {
        var viewModels: [TutorialViewModel] = []

        viewModels.append(TutorialViewModel(details: R.string.localizable.tutorial1Details(),
                                            imageName: R.image.tutorial1.name))

        viewModels.append(TutorialViewModel(details: R.string.localizable.tutorial2Details(),
                                            imageName: R.image.tutorial2.name))

        viewModels.append(TutorialViewModel(details: R.string.localizable.tutorial3Details(),
                                            imageName: R.image.tutorial3.name))

        view?.didReceive(viewModels: viewModels)
    }

    init(legalData: LegalData) {
        self.legalData = legalData
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func activateTerms() {
        if let view = view {
            wireframe.showWeb(url: legalData.termsUrl,
                              from: view,
                              style: .modal)
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(url: legalData.privacyPolicyUrl,
                              from: view,
                              style: .modal)
        }
    }

    func viewIsReady() {
        provideTutorialViewModels()

        interactor.setup()
    }

    func activateSignup() {
        interactor.prepareSignup()
    }

    func activateAccountRestore() {
        interactor.prepareRestore()
    }
}

extension OnboardingMainPresenter: OnboardingMainOutputInteractorProtocol {
    func didStartSignupPreparation() {
        view?.didStartLoading()
    }

    func didFinishSignupPreparation() {
        view?.didStopLoading()
        wireframe.showSignup(from: view)
    }

    func didReceiveSignupPreparation(error: Error) {
        view?.didStopLoading()
        _ = wireframe.present(error: error, from: view)
    }

    func didStartRestorePreparation() {
        view?.didStartLoading()
    }

    func didFinishRestorePreparation() {
        view?.didStopLoading()
        wireframe.showAccountRestore(from: view)
    }

    func didReceiveRestorePreparation(error: Error) {
        view?.didStopLoading()
        _ = wireframe.present(error: error, from: view)
    }

    func didReceiveVersion(data: SupportedVersionData) {
        if !data.supported {
            view?.didStopLoading()

            wireframe.presentUnsupportedVersion(for: data, on: view?.controller.view.window, animated: true)
        }
    }
}
