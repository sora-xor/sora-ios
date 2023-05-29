import SoraUIKit
import SoraFoundation
import SCard

final class LanguagePresenter {
    weak var view: LanguageViewProtocol?
    
    private var selectedLanguage: Language?
    
    private func createModel() -> LanguageModel {
        selectedLanguage = localizationManager?.selectedLanguage
        var sections: [SoramitsuTableViewSection] = []
        
        sections.append(languageSection())
        
        return LanguageModel(title: R.string.localizable.changeLanguage(preferredLanguages: languages),
                             sections: sections)
    }
    
    private func languageSection() -> SoramitsuTableViewSection {
        let languages: [Language]? = localizationManager?.availableLocalizations.map { Language(code: $0) }
        
        guard let languages = languages else {
            return SoramitsuTableViewSection(rows: [])
        }
        
        let items: [SoramitsuTableViewItemProtocol] = languages.map {
            let isSelected: Bool = $0.code == selectedLanguage?.code
            let title: String
            let code = $0.code

            let targetLocale = Locale(identifier: $0.code)
            let subtitle: String = $0.title(in: targetLocale)?.capitalized ?? ""

            if let localizationManager = localizationManager {
                let language = $0.title(in: localizationManager.selectedLocale)?.capitalized ?? ""

                if let regionTitle = $0.region(in: localizationManager.selectedLocale) {
                    title = "\(language) (\(regionTitle))"
                } else {
                    title = language
                }
            } else {
                title = ""
            }
            
            return LanguageItem(code: code, title: title, subtitle: subtitle, selected: isSelected) { [weak self] in
                self?.localizationManager?.selectedLocalization = code
                UIView.appearance().semanticContentAttribute = code == "ar" ? .forceRightToLeft : .forceLeftToRight
            }
        }
        
        return SoramitsuTableViewSection(rows: items)
    }
    
}

extension LanguagePresenter: LanguagePresenterProtocol {
    func reload() {
        let model = createModel()
        view?.update(model: model)
    }
}

extension LanguagePresenter: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        let model = createModel()
        view?.update(model: model)
    }
}
