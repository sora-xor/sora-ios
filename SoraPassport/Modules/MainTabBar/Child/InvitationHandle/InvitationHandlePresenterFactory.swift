import Foundation
//import SoraCrypto
import SoraFoundation

final class InvitationHandlePresenterFactory: InvitationHandlePresenterFactoryProtocol {
    static func createPresenter(for view: ControllerBackedProtocol) -> InvitationHandlePresenterProtocol? {
//        guard let requestSigner = DARequestSigner.createDefault() else {
//            return nil
//        }
//
//        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

//        let projectService = ProjectUnitService(unit: projectUnit)
//        projectService.requestSigner = requestSigner
//
//        let userDataProvider = CustomerDataProviderFacade.shared.userProvider
//
//        let interactor = InvitationHandleInteractor(projectService: projectService,
//                                                    userDataProvider: userDataProvider,
//                                                    eventCenter: EventCenter.shared)
        let presenter = InvitationHandlePresenter(localizationManager: LocalizationManager.shared)
        let wireframe = InvitationHandleWireframe()

        presenter.view = view
//        presenter.interactor = interactor
        presenter.wireframe = wireframe
//        interactor.presenter = presenter

        return presenter
    }
}
