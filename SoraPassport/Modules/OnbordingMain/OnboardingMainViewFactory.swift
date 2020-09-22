import Foundation
import SoraKeystore
import SoraFoundation

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

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let legalData = LegalData(termsUrl: applicationConfig.termsURL,
                              privacyPolicyUrl: applicationConfig.privacyPolicyURL)

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.legal(for: locale)
        view.locale = locale

        let presenter = OnboardingMainPresenter(legalData: legalData, locale: locale)
        let wireframe = OnboardingMainWireframe()

        let interactor = createInteractor(for: applicationConfig,
                                          decentralizedResolverUrl: decentralizedResolverUrl,
                                          invitationLinkService: invitationLinkService)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for config: ApplicationConfigProtocol,
                                         decentralizedResolverUrl: URL,
                                         invitationLinkService: InvitationLinkServiceProtocol)
        -> OnboardingMainInteractor {
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
            applicationConfig: config)

        let interactor = OnboardingMainInteractor(onboardingPreparationService: onboardingPreparationService,
                                                  settings: settings,
                                                  keystore: keystore,
                                                  identityNetworkOperationFactory: identityNetworkOperationFactory,
                                                  identityLocalOperationFactory: IdentityOperationFactory(),
                                                  operationManager: OperationManagerFacade.sharedManager)
        interactor.logger = Logger.shared

        return interactor
    }
}
