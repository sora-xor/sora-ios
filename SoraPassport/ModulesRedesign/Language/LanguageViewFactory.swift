import SoraFoundation

final class LanguageViewFactory {
    static func createView() -> LanguageViewProtocol {
        let view = LanguageView()
        let presenter = LanguagePresenter()
        presenter.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        return view

    }
}
