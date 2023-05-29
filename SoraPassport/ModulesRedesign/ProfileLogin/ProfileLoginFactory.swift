import SoraFoundation

final class ProfileLoginFactory {
    static func createView() -> ProfileLoginViewProtocol {
        let view = ProfileLoginView()
        let presenter = ProfileLoginPresenter()
        presenter.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        return view
    }
}
