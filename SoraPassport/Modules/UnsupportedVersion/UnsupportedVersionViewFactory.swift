import Foundation
import SoraFoundation

final class UnsupportedVersionViewFactory: UnsupportedVersionViewFactoryProtocol {
    static func createView(supportedVersionData: SupportedVersionData) -> UnsupportedVersionViewProtocol? {
        let view = UnsupportedVersionViewController(nib: R.nib.unsupportedVersionViewController)
        let presenter = UnsupportedVersionPresenter(locale: LocalizationManager.shared.selectedLocale,
                                                    supportedVersionData: supportedVersionData)
        let interactor = UnsupportedVersionInteractor()
        let wireframe = UnsupportedVersionWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
