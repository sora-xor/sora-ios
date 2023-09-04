import Foundation
import SoraKeystore
import SoraFoundation
import SSFCloudStorage

final class OnboardingMainViewFactory {
    
    static func createWelcomeView(endAddingBlock: (() -> Void)? = nil) -> OnboardingMainViewProtocol? {
        guard let kestoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let view = WelcomeViewController()

        let presenter = OnboardingMainPresenter(locale: locale)
        let wireframe = OnboardingMainWireframe()
        wireframe.endAddingBlock = endAddingBlock

        let interactor = OnboardingMainInteractor(keystoreImportService: kestoreImportService,
                                                  backupService: CloudStorageService(uiDelegate: view))

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return view
    }
}
