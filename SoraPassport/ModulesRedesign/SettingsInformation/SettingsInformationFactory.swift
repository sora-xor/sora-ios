import SoraFoundation

final class SettingsInformationFactory {
    static func createInformation() -> SettingsInformationViewProtocol {
        let view = SettingsInformationViewController()
        let presenter = SettingsInformationPresenter()
        presenter.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        return view
    }
}
