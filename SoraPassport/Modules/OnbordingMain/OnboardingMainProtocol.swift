/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModels: [TutorialViewModelProtocol])
}

protocol OnboardingMainPresenterProtocol: class {
    func viewIsReady()
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
    func activatePrivacy()
}

protocol OnboardingMainInputInteractorProtocol: class {
    func setup()
    func prepareSignup()
    func prepareRestore()
}

protocol OnboardingMainOutputInteractorProtocol: class {
    func didStartSignupPreparation()
    func didFinishSignupPreparation()
    func didReceiveSignupPreparation(error: Error)

    func didStartRestorePreparation()
    func didFinishRestorePreparation()
    func didReceiveRestorePreparation(error: Error)

    func didReceiveVersion(data: SupportedVersionData)
}

protocol OnboardingMainWireframeProtocol: WebPresentable, ErrorPresentable,
AlertPresentable, UnsupportedVersionPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainViewFactoryProtocol: WebPresentable {
    static func createView() -> OnboardingMainViewProtocol?
}
