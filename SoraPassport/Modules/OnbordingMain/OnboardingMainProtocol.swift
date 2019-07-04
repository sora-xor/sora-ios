/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol OnboardingMainViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [TutorialViewModelProtocol])
}

protocol OnboardingMainPresenterProtocol: class {
    func viewIsReady()
    func activateSignup()
    func activateAccountRestore()
    func activateTerms()
}

protocol OnboardingMainWireframeProtocol: WebPresentable {
    func showSignup(from view: OnboardingMainViewProtocol?)
    func showAccountRestore(from view: OnboardingMainViewProtocol?)
}

protocol OnboardingMainViewFactoryProtocol: WebPresentable {
    static func createView() -> OnboardingMainViewProtocol?
}
