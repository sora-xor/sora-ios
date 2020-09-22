import UIKit
import SoraFoundation

final class ProfileViewFactory: ProfileViewFactoryProtocol {
	static func createView() -> ProfileViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = ProfileViewModelFactory(votesFormatter: NumberFormatter.vote
                                                                .localizableResource(),
                                                              integerFormatter: NumberFormatter.anyInteger
                                                                .localizableResource())

        let view = ProfileViewController(nib: R.nib.profileViewController)
        let presenter = ProfilePresenter(viewModelFactory: profileViewModelFactory)
        let interactor = ProfileInteractor(customerDataProviderFacade: CustomerDataProviderFacade.shared)
        let wireframe = ProfileWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        presenter.logger = Logger.shared

        return view
	}
}
