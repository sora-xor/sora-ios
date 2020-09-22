import Foundation
import SoraCrypto
import SoraUI
import SoraFoundation

final class InvitationViewFactory: InvitationViewFactoryProtocol {
    static func createView() -> InvitationViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let view = InvitationViewController(nib: R.nib.invitationViewController)

        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)
        let timerFactory = CountdownTimerFactory()

        let integerFormatter = NumberFormatter.anyInteger.localizableResource()
        let invitationViewModelFactory = InvitationViewModelFactory(integerFormatter: integerFormatter)

        let presenter = InvitationPresenter(invitationViewModelFactory: invitationViewModelFactory,
                                            timerFactory: timerFactory,
                                            invitationFactory: invitationFactory)

        let projectUnitService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectUnitService.requestSigner = requestSigner

        let interator = InvitationInteractor(customerDataProviderFacade: CustomerDataProviderFacade.shared,
                                             eventCenter: EventCenter.shared)
        let wireframe = InvitationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interator
        presenter.wireframe = wireframe
        interator.presenter = presenter

        view.localizationManager = localizationManager

        presenter.localizationManager = localizationManager
        presenter.logger = Logger.shared

        return view
    }
}
