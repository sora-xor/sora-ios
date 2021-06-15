import Foundation
import SoraFoundation

final class AboutViewFactory: AboutViewFactoryProtocol {
    static func createView() -> AboutViewProtocol? {

        let aboutViewModelFactory = AboutViewModelFactory()

        let presenter = AboutPresenter(viewModelFactory: aboutViewModelFactory)
        presenter.localizationManager = LocalizationManager.shared

        let view = AboutViewController(nib: R.nib.aboutViewController)
        view.localizationManager = LocalizationManager.shared

        view.presenter = presenter

        presenter.view = view

        let wireframe = AboutWireframe()
        presenter.wireframe = wireframe

        return view
    }
}
