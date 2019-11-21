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

        guard let invitationLinkService: InvitationLinkServiceProtocol = DeepLinkService.shared
            .findService() else {
            Logger.shared.error("Can't find invitation link service")
            return nil
        }

        let legalData = LegalData(termsUrl: applicationConfig.termsURL,
                              privacyPolicyUrl: applicationConfig.privacyPolicyURL)

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.legal

        let presenter = OnboardingMainPresenter(legalData: legalData)
        let wireframe = OnboardingMainWireframe()

        let projectOperationFactory = ProjectOperationFactory()
        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: decentralizedResolverUrl)
        let deviceInfoFactory = DeviceInfoFactory()
        let settings = SettingsManager.shared
        let keystore = Keychain()

        let onboardingPreparationService = OnboardingPreparationService(
            accountOperationFactory: projectOperationFactory,
            informationOperationFactory: projectOperationFactory,
            invitationLinkService: invitationLinkService,
            deviceInfoFactory: deviceInfoFactory,
            keystore: keystore,
            settings: settings,
            applicationConfig: applicationConfig)

        let interactor = OnboardingMainInteractor(onboardingPreparationService: onboardingPreparationService,
                                                  settings: settings,
                                                  keystore: keystore,
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
