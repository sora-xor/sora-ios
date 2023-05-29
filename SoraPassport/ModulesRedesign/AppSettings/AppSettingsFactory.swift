import SoraFoundation

final class AppSettingsFactory {
    static func createAppSettings() -> AppSettingsViewProtocol {
        let view = AppSettingsView()
        let presenter = AppSettingsPresenter()
        presenter.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        return view

    }
}
