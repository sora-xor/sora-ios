// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import SoraUIKit
import SoraFoundation
import SCard

final class LanguagePresenter {
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
