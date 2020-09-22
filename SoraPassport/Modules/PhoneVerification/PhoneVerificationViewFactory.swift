import UIKit
import SoraCrypto
import SoraKeystore
import SoraFoundation

final class PhoneVerificationViewFactory: PhoneVerificationViewFactoryProtocol {
	static func createView(with form: PersonalForm) -> PhoneVerificationViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            return nil
        }

        let locale = LocalizationManager.shared.selectedLocale

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let projectService = ProjectUnitService(unit: projectUnit)
        projectService.requestSigner = requestSigner

        let view = PhoneVerificationViewController(nib: R.nib.phoneVerificationViewController)
        let presenter = PhoneVerificationPresenter(locale: locale)
        let interactor = PhoneVerificationInteractor(projectService: projectService, settings: SettingsManager.shared)
        let wireframe = PhoneVerificationWireframe(form: form)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        presenter.logger = Logger.shared

        return view
	}
}
