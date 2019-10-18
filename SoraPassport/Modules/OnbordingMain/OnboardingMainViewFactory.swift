/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createView() -> OnboardingMainViewProtocol? {
        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        guard let decentralizedResolverUrl = URL(string: applicationConfig.didResolverUrl) else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let legalData = LegalData(termsUrl: applicationConfig.termsURL,
                              privacyPolicyUrl: applicationConfig.privacyPolicyURL)

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.legal

        let presenter = OnboardingMainPresenter(legalData: legalData)
        let wireframe = OnboardingMainWireframe()

        let informationFactory = ProjectOperationFactory()
        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: decentralizedResolverUrl)

        let interactor = OnboardingMainInteractor(applicationConfig: ApplicationConfig.shared,
                                                  settings: SettingsManager.shared,
                                                  keystore: Keychain(),
                                                  informationOperationFactory: informationFactory,
                                                  identityNetworkOperationFactory: identityNetworkOperationFactory,
                                                  identityLocalOperationFactory: IdentityOperationFactory.self,
                                                  operationManager: OperationManager.shared)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter
        interactor.logger = Logger.shared

        return view
    }
}
