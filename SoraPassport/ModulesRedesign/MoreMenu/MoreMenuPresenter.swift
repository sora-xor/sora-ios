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
import SoraKeystore
import SoraUIKit


class MoreMenuSection {
    var id = UUID()
    var items: [MoreMenuItem]
    
    init(items: [MoreMenuItem]) {
        self.items = items
    }
}

extension MoreMenuSection: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MoreMenuSection, rhs: MoreMenuSection) -> Bool {
        lhs.id == rhs.id
    }
}


final class MoreMenuPresenter: MoreMenuPresenterProtocol {
    weak var view: MoreMenuViewProtocol?
    var wireframe: MoreMenuWireframeProtocol!
    
    init() {
        SoramitsuUI.updates.addObserver(self)
        EventCenter.shared.add(observer: self)
    }

    func reload() {
        view?.set(title: R.string.localizable.commonMore(preferredLanguages: languages))
        
        let snapshot = createSnapshot()
        view?.update(snapshot: snapshot)
    }

    private func createSnapshot() -> MoreMenuSnapshot {
        var snapshot = MoreMenuSnapshot()
        
        let sections = [firstSection(), secondSection(), thirdSection()]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func firstSection() -> MoreMenuSection {
        var items: [MoreMenuItem] = []
        let accounts = MoreMenuItem(title: R.string.localizable.settingsCryptoAccounts(preferredLanguages: languages),
                                    subtitle: R.string.localizable.settingsAccountsSubtitle(preferredLanguages: languages),
                                    picture: .icon(image: R.image.iconStar2()!,
                                                   color: .accentTertiary),
                                    onTap: { self.showAccounts() })
        items.append(accounts)
        
        return MoreMenuSection(items: items)
    }

    private func secondSection() -> MoreMenuSection {
        var items: [MoreMenuItem] = []
        let nodes = MoreMenuItem(title: R.string.localizable.settingsNodes(preferredLanguages: languages),
                                 subtitle: nodeName(), //TODO: node address/description here
                                 picture: .icon(image: R.image.iconNode()!,
                                                color: .accentTertiary),
                                 circleColor: .statusSuccess,
                                 onTap: { self.showNodes()}
        )
        let appSettings = MoreMenuItem(title: R.string.localizable.settingsHeaderApp(preferredLanguages: languages),
                                       subtitle: R.string.localizable.settingsAppSubtitle(preferredLanguages: languages),
                                       picture: .icon(image: R.image.iconSettingsAltFill()!,
                                                      color: .accentTertiary),
                                       onTap: { self.showAppSettings() }
        )
        let login = MoreMenuItem(title: R.string.localizable.settingsLoginTitle(preferredLanguages: languages),
                                 subtitle: R.string.localizable.settingsLoginSubtitle(preferredLanguages: languages),
                                 picture: .icon(image: R.image.iconBiometric()!,
                                                color: .accentTertiary),
                                 onTap: { self.showLoginAndSecurity() }
        )
        items.append(nodes)
        items.append(appSettings)
        items.append(login)

        return MoreMenuSection(items: items)
    }

    private func nodeName() -> String {
        let chain = ChainRegistryFacade.sharedRegistry.getChain(for: Chain.sora.genesisHash())!
        let node = ChainRegistryFacade.sharedRegistry.getActiveNode(for: chain.chainId)
        return node?.name ?? " "
    }

    private func thirdSection() -> MoreMenuSection {
        var items: [MoreMenuItem] = []
        let inviteFriends = MoreMenuItem(title: R.string.localizable.settingsInviteTitle(preferredLanguages: .currentLocale) ,
                                         subtitle: R.string.localizable.settingsInviteSubtitle(preferredLanguages: .currentLocale),
                                         picture: .icon(image: R.image.about.support()! ,
                                                        color: .accentTertiary),
                                         onTap: { self.showInviteFriends() }
        )
        let information = MoreMenuItem(title: R.string.localizable.settingsInformationTitle(preferredLanguages: languages),
                                       subtitle: R.string.localizable.settingsInformationSubtitle(preferredLanguages: languages),
                                       picture: .icon(image: R.image.iconInfo()!,
                                                      color: .accentTertiary),
                                       onTap: { self.showInformation() }
        )
        
        items.append(inviteFriends)
        items.append(information)
        
        return MoreMenuSection(items: items)
    }

    func showAppSettings() {
        wireframe.showAppSettings(from: view)
    }

    func showAccounts() {
        wireframe.showChangeAccountView(from: view)
    }

    func showNexusPortfolio() {
        wireframe.showNexusPortfolio(from: view)
    }

    func showPolkamarkt() {
        wireframe.showPolkamarkt(from: view)
    }

    func showNodes() {
        wireframe.showNodes(from: view)
    }

    func showInviteFriends() {
        wireframe.showFriendsView(from: view)
    }

    func showInformation() {
        wireframe.showInformation(from: view)
    }

    func showLoginAndSecurity() {
        wireframe.showSecurity(from: view)
    }
}

extension MoreMenuPresenter: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}

extension MoreMenuPresenter: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.reload()
        }
    }
    
    func processLanguageChanged(event: LanguageChanged) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.refreshNavigationBar()
        }
    }
}

extension MoreMenuPresenter: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.refreshNavigationBar()
        }
    }
}
