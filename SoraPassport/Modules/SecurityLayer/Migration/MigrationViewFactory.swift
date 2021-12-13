import Foundation
import SoraFoundation

class MigrationViewFactory {
    static func createView(with service: MigrationServiceProtocol) -> MigrationViewProtocol? {

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let view = MigrationViewController(nib: R.nib.migrationViewController)
        let presenter = MigrationPresenter(email: applicationConfig.supportEmail, locale: locale)
        let interactor = MigrationInteractor(migrationService: service)
        let wireframe = MigrationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
