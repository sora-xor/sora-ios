import Foundation
import SoraCrypto
import SoraKeystore

final class PhoneRegistrationViewFactory: PhoneRegistrationViewFactoryProtocol {
    static func createView(with country: Country) -> PhoneRegistrationViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            return nil
        }

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let projectService = ProjectUnitService(unit: projectUnit)
        projectService.requestSigner = requestSigner

        let view = PhoneRegistrationViewController(nib: R.nib.phoneRegistrationViewController)
        let presenter = PhoneRegistrationPresenter(country: country)
        let interactor = PhoneRegistrationInteractor(accountService: projectService,
                                                     settings: SettingsManager.shared)
        let wireframe = PhoneRegistrationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
