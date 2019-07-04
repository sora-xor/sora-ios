/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var wireframe: OnboardingMainWireframeProtocol!

    var termsData: WebData

    private func provideTutorialViewModels() {
        var viewModels: [TutorialViewModel] = []

        viewModels.append(TutorialViewModel(title: R.string.localizable.tutorial1Title(),
                                            details: R.string.localizable.tutorial1Details(),
                                            imageName: R.image.tutorial1.name))

        viewModels.append(TutorialViewModel(title: R.string.localizable.tutorial2Title(),
                                            details: R.string.localizable.tutorial2Details(),
                                            imageName: R.image.tutorial2.name))

        viewModels.append(TutorialViewModel(title: R.string.localizable.tutorial3Title(),
                                            details: R.string.localizable.tutorial3Details(),
                                            imageName: R.image.tutorial3.name))

        view?.didReceive(viewModels: viewModels)
    }

    init(termsData: WebData) {
        self.termsData = termsData
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func activateTerms() {
        if let view = view {
            wireframe.showWeb(url: termsData.url,
                              from: view,
                              secondaryTitle: termsData.title)
        }
    }

    func viewIsReady() {
        provideTutorialViewModels()
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        wireframe.showAccountRestore(from: view)
    }
}
