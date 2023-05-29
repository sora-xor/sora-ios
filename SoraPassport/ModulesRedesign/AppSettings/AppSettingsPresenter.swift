import SoraFoundation
import SoraUIKit

protocol AppSettingsPresenterProtocol: AnyObject {
    var view: AppSettingsViewProtocol? { get set }
    
    func reload()
}


final class AppSettingsPresenter: AppSettingsPresenterProtocol {
    weak var view: AppSettingsViewProtocol?
    
    func reload() {
        let model = createModel()
        view?.update(model: model)
    }
    
    private func createModel() -> AppSettingsModel {
        var sections: [SoramitsuTableViewSection] = []
        
        sections.append(languageSection())
        
        return AppSettingsModel(title: R.string.localizable.settingsHeaderApp(preferredLanguages: languages),
                                sections: sections)
    }
    
    private func languageSection() -> SoramitsuTableViewSection {
        var items: [SoramitsuTableViewItemProtocol] = []
        let languages = AppSettingsItem(title: R.string.localizable.changeLanguage(preferredLanguages: languages),
                                        picture: .icon(image: R.image.profile.language()!,
                                                       color: .fgSecondary),
                                        rightItem: .arrow,
                                        onTap: { self.showLanguages() }
        )
        items.append(languages)
        return SoramitsuTableViewSection(rows: items)
    }
    
    private func appearanceSection() -> SoramitsuTableViewSection {
        let systemOn = SoramitsuUI.shared.themeMode == .system
        let darkOn = SoramitsuUI.shared.themeMode == .manual(.dark)
        
        var items: [AppSettingsItem] = []
        
        let systemAppearance = AppSettingsItem(title: R.string.localizable.systemAppearance(preferredLanguages: languages),
                                               rightItem: .switcher(state: systemOn ? .on : .off),
                                               onSwitch: { [weak self] on in
            SoramitsuUI.shared.themeMode = on ? .system : .manual(.light)
            self?.reload()
            
        })
        let darkMode = AppSettingsItem(title: R.string.localizable.darkMode(preferredLanguages: languages),
                                       rightItem: .switcher(state: darkOn ? .on : .off),
                                       onSwitch: { [weak self] on in
            SoramitsuUI.shared.themeMode = on ? .manual(.dark) : .manual(.light)
            self?.reload()
        })
        items.append(systemAppearance)
        items.append(darkMode)
        let card = AppSettingsCardItem(title: R.string.localizable.appearanceTitle(preferredLanguages: languages).uppercased(),
                                       menuItems: items)
        return SoramitsuTableViewSection(rows: [card])
    }
    
    private func showLanguages() {
        let languageView = LanguageViewFactory.createView()
        
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        
        languageView.controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(languageView.controller, animated: true)
    }
}

extension AppSettingsPresenter: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let model = createModel()
        view?.update(model: model)
    }
}
