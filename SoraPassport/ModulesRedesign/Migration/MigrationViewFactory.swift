import Foundation
import SoraFoundation

class MigrationViewFactory {    
    static func createViewRedesign(with service: MigrationServiceProtocol) -> MigrationViewProtocol? {

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let view = MigrationRedesignViewController()
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
