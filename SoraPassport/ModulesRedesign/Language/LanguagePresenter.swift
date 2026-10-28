// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SoraUIKit
import SoraFoundation

final class LanguagePresenter {
    private static let oldAkkadianCode = "akk"
    private static let oldAkkadianTitle = "Old Akkadian"
    private static let oldAkkadianNativeTitle = "lišānum akkadītum labīrtum"
    private static let middleEgyptianCode = "egy-Egyp"
    private static let middleEgyptianTitle = "Middle Egyptian (Hieroglyphic)"
    private static let middleEgyptianNativeTitle = "𓌃𓂧𓅱𓀁 𓈖 𓆎𓅓𓏏𓊖"

    weak var view: LanguageViewProtocol?
    let eventCenter: EventCenterProtocol
    private var selectedLanguage: Language?
    
    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
        eventCenter.add(observer: self, dispatchIn: .main)
    }
    
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
            let subtitle: String
            switch code {
            case Self.oldAkkadianCode:
                subtitle = Self.oldAkkadianNativeTitle
            case Self.middleEgyptianCode:
                subtitle = Self.middleEgyptianNativeTitle
            default:
                subtitle = $0.title(in: targetLocale)?.capitalized ?? ""
            }

            if code == Self.oldAkkadianCode {
                title = Self.oldAkkadianTitle
            } else if code == Self.middleEgyptianCode {
                title = Self.middleEgyptianTitle
            } else if let localizationManager = localizationManager {
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
                
                guard let delegate = UIApplication.shared.delegate as? AppDelegate else { return }
                delegate.setupLanguage()
                EventCenter.shared.notify(with: LanguageChanged())
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

extension LanguagePresenter: EventVisitorProtocol {
    func processLanguageChanged(event: LanguageChanged) {
        view?.updateLayout()
    }
}
