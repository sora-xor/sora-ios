/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createView() -> OnboardingMainViewProtocol? {
        let termsData = WebData(title: R.string.localizable.termsTitle(),
                                url: ApplicationConfig.shared.termsURL)

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.terms

        let presenter = OnboardingMainPresenter(termsData: termsData)
        let wireframe = OnboardingMainWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
