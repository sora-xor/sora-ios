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
        sections.append(appearanceSection())
        
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
