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
import SoraUIKit
import SCard


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
        
        if ConfigService.shared.config.isSoraCardEnabled,
           let scard = SCard.shared
        {
            let subtitleStream: AsyncStream<String?> = scard.userStatusStream.map { userState in
                return userState.text
            }

            let circleColorStream = scard.userStatusStream.map { userState in
                var circleColor: SoramitsuColor?
                switch userState {
                case .none, .notStarted, .successful, .userCanceled:
                    circleColor = nil
                case .pending:
                    circleColor = .statusWarning
                case .rejected:
                    circleColor = .statusError
                }
                return circleColor
            }

            let soraCard = MoreMenuItem(
                title: R.string.localizable.moreMenuSoraCardTitle(preferredLanguages: languages),
                subtitle: scard.currentUserState.text,
                subtitleStream: subtitleStream,
                picture: .icon(image: R.image.iconCard()!, color: .accentTertiary),
                circleColorStream: circleColorStream,
                onTap: { self.showSoraCard() }
            )

            items.append(soraCard)
        }

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

    func showSoraCard() {
        wireframe.showSoraCard(from: view)
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
