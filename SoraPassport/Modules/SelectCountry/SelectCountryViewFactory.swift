import Foundation

final class SelectCountryViewFactory: SelectCountryViewFactoryProtocol {
    static func createView() -> SelectCountryViewProtocol? {
        let countryProvider = InformationDataProviderFacade.shared.countryDataProvider

        let view = SelectCountryViewController(nib: R.nib.selectCountryViewController)
        let presenter = SelectCountryPresenter()
        let interactor = SelectCountryInteractor(countryProvider: countryProvider)
        let wireframe = SelectCountryWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.logger = Logger.shared

        return view
    }
}
