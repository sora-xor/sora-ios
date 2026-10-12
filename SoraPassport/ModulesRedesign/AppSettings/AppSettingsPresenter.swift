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

import SoraFoundation
import SoraKeystore
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
        let tairaAdmitted = NexusNetworkAdmissionPolicy
            .current.isTairaAdmitted
        if ProductSurfacePolicy.showsTairaSettings,
           NexusPortfolioPresentationPolicy.exposesTairaSettings(
               tairaAdmitted: tairaAdmitted
           ) {
            sections.append(networksSection())
        }
        
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
        let selected: Int
        switch SoramitsuUI.shared.themeMode {
        case .system: selected = 0
        case .manual(.dark): selected = 1
        case .manual(.light): selected = 2
        }
        let theme = AppAppearanceItem(
            title: R.string.localizable.appearanceTitle(preferredLanguages: languages).uppercased(),
            choices: [R.string.localizable.neonThemeSystem(preferredLanguages: languages),
                      R.string.localizable.neonThemeDark(preferredLanguages: languages),
                      R.string.localizable.neonThemeLight(preferredLanguages: languages)],
            selectedIndex: selected
        ) { [weak self] choice in
            switch choice {
            case 0: SoramitsuUI.shared.themeMode = .system
            case 1: SoramitsuUI.shared.themeMode = .manual(.dark)
            case 2: SoramitsuUI.shared.themeMode = .manual(.light)
            default: return
            }
            self?.reload()
        }
        let reduceEffects = AppSettingsItem(
            title: R.string.localizable.neonReduceEffects(preferredLanguages: languages),
            rightItem: .switcher(state: FxPolicy.reduceEffects ? .on : .off),
            onSwitch: { [weak self] enabled in
                FxPolicy.reduceEffects = enabled
                self?.reload()
            }
        )
        let card = AppSettingsCardItem(title: nil, menuItems: [reduceEffects])
        return SoramitsuTableViewSection(rows: [theme, card])
    }

    private func networksSection() -> SoramitsuTableViewSection {
        let settings = SettingsManager.shared
        let taira = AppSettingsItem(
            title: "Taira testnet",
            rightItem: .switcher(state: settings.isTairaEnabled ? .on : .off),
            onSwitch: { [weak self] enabled in
                // The setter records an explicit choice, so a future remote
                // default can never override what the user selected.
                settings.isTairaEnabled = enabled
                self?.reload()
            }
        )
        let card = AppSettingsCardItem(
            title: "TEST NETWORKS",
            menuItems: [taira]
        )
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
