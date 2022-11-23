import UIKit
import SoraKeystore
import SoraFoundation

final class PersonalUpdateViewFactory: PersonalUpdateViewFactoryProtocol {
	static func createView() -> PersonalUpdateViewProtocol? {

        let view = PersonalUpdateViewController(nib: R.nib.personalUpdateViewController)
        view.localizationManager = LocalizationManager.shared

        let viewModelFactory = PersonalInfoViewModelFactory()
        let presenter = PersonalUpdatePresenter(viewModelFactory: viewModelFactory)
        presenter.localizationManager = LocalizationManager.shared

        let accountSettings = SelectedWalletSettings.shared
        let interactor = PersonalUpdateInteractor(settingsManager: accountSettings)
        let wireframe = PersonalUpdateWireframe()

        view.presenter = presenter

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return view
	}
}
