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

typealias SettingsInformationDataSource = UITableViewDiffableDataSource<SettingsInformationSection, InformationItem>
typealias SettingsInformationSnapshot = NSDiffableDataSourceSnapshot<SettingsInformationSection, InformationItem>

class SettingsInformationSection {
    var id = UUID()
    var items: [InformationItem]
    
    init(items: [InformationItem]) {
        self.items = items
    }
}

extension SettingsInformationSection: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SettingsInformationSection, rhs: SettingsInformationSection) -> Bool {
        lhs.id == rhs.id
    }
}


protocol SettingsInformationPresenterProtocol: AnyObject {
    var view: SettingsInformationViewController? { get set }
    func reload()
}

final class SettingsInformationPresenter: SettingsInformationPresenterProtocol {
    weak var view: SettingsInformationViewController?
    
    func reload() {
        view?.set(title: R.string.localizable.settingsInformationTitle(preferredLanguages: languages))
        
        let snapshot = createSnapshot()
        view?.update(snapshot: snapshot)
    }
    
    private func createSnapshot() -> SettingsInformationSnapshot {
        var snapshot = SettingsInformationSnapshot()
        
        let sections = [faqSection(), termsSection(), linksSection()]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func position(_ items: inout [InformationItem]) {
        items.first?.position = .first
        items.last?.position = .last
    }
    
    private func faqSection() -> SettingsInformationSection {
        var items: [InformationItem] = [
            InformationItem(title: R.string.localizable.profileFaqTitle(preferredLanguages: languages),
                            picture: .icon(image: R.image.profile.faq()!,
                                           color: .fgSecondary),
                            rightItem: .arrow,
                            onTap: { self.open(url: ApplicationConfig.shared.faqURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutAskSupport(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.supportURL.absoluteString,
                            picture: .icon(image: R.image.about.support()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.supportURL) }
                           )
        ]
        
        position(&items)

        return SettingsInformationSection(items: items)
    }
    
    private func termsSection() -> SettingsInformationSection {
        var items: [InformationItem] = [
            InformationItem(title: R.string.localizable.polkaswapInfoTitle2(preferredLanguages: languages),
                            picture: .icon(image: R.image.profile.disclaimer()!,
                                           color: .fgSecondary),
                            rightItem: .arrow,
                            onTap: { self.showDisclaimer() }
                           ),
            InformationItem(title: R.string.localizable.aboutTerms(preferredLanguages: languages),
                            picture: .icon(image: R.image.about.terms()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.termsURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutPrivacy(preferredLanguages: languages),
                            picture: .icon(image: R.image.about.policy()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.privacyPolicyURL) }
                           )
        ]
        
        position(&items)

        return SettingsInformationSection(items: items)
    }
    
    private func linksSection() -> SettingsInformationSection {
        var items: [InformationItem] = [
            InformationItem(title: R.string.localizable.aboutWebsite(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.siteURL.absoluteString,
                            picture: .icon(image: R.image.about.website()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.siteURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutSourceCode(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.opensourceURL.absoluteString,
                            picture: .icon(image: R.image.about.github()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.opensourceURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutTwitter(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.twitterURL.absoluteString,
                            picture: .icon(image: R.image.about.twitter()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.twitterURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutYoutube(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.youtubeURL.absoluteString,
                            picture: .icon(image: R.image.about.youtube()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.youtubeURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutInstagram(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.instagramURL.absoluteString,
                            picture: .icon(image: R.image.about.instagram()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.instagramURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutMedium(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.mediumURL.absoluteString,
                            picture: .icon(image: R.image.about.medium()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.mediumURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutWiki(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.wikiURL.absoluteString,
                            picture: .icon(image: R.image.about.wiki()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.wikiURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutTelegram(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.telegramURL.absoluteString,
                            picture: .icon(image: R.image.about.telegram()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.telegramURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutAnnouncements(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.announcementsURL.absoluteString,
                            picture: .icon(image: R.image.about.announcements()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.open(url: ApplicationConfig.shared.announcementsURL) }
                           ),
            InformationItem(title: R.string.localizable.aboutContactUs(preferredLanguages: languages),
                            subtitle: ApplicationConfig.shared.supportEmail,
                            picture: .icon(image: R.image.about.email()!,
                                           color: .fgSecondary),
                            rightItem: .link,
                            onTap: { self.mail() }
                           )
        ]
        
        position(&items)

        return SettingsInformationSection(items: items)
    }
    
    private func showDisclaimer() {
        guard let containerView = MainTabBarViewFactory.swapDisclamerController(completion: {
            UserDefaults.standard.set(true, forKey: "isDisclamerShown")
        }) else { return }

        view?.controller.present(containerView, animated: true)
    }
    
    private func open(url: URL) {
        let webViewController = WebViewFactory.createWebViewController(for: url,
                                                                       style: .automatic)
        
        view?.controller.present(webViewController, animated: true, completion: nil)
    }
    
    private func mail() {
        guard let view = view else {
            return
        }
        writeEmail(with: SocialMessage(body: nil, subject: nil, recepients: [ApplicationConfig.shared.supportEmail]),
                   from: view,
                   completionHandler: nil)
    }
    
    private func pushView(_ viewToPush: ControllerBackedProtocol) {
        guard let navigationController = view?.controller.navigationController else { return }
        
        viewToPush.controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(viewToPush.controller, animated: true)
    }
}

extension SettingsInformationPresenter: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        reload()
    }
}


extension SettingsInformationPresenter: EmailPresentable {}
