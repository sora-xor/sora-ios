import Foundation
import SoraFoundation

final class FriendsViewFactory: FriendsViewFactoryProtocol {
    static func createView() -> FriendsViewProtocol? {

        let view = FriendsViewController(nib: R.nib.friendsViewController)
        view.localizationManager = LocalizationManager.shared

        let timerFactory = CountdownTimerFactory()
        let invitationFactory = InvitationFactory(
            host: ApplicationConfig.shared.invitationHostURL
        )
        let friendsViewModelFactory = FriendsViewModelFactory()
        let rewardsViewModelFactory = RewardsViewModelFactory()

        let presenter = FriendsPresenter(
            timerFactory: timerFactory,
            invitationFactory: invitationFactory,
            friendsViewModelFactory: friendsViewModelFactory,
            rewardsViewModelFactory: rewardsViewModelFactory
        )
        presenter.localizationManager = LocalizationManager.shared

        let interactor = FriendsInteractor(
//            customerDataProviderFacade: CustomerDataProviderFacade.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = FriendsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
