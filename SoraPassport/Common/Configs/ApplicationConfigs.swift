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

import Foundation
import os
import SoraKeystore

enum Constants {
    static let apyTitle = "SB APY"
}

protocol ApplicationConfigProtocol {
    var projectDecentralizedId: String { get }
    var notificationDecentralizedId: String { get }
    var notificationOptions: UInt8 { get }
    var walletDecentralizedId: String { get }
    var didResolverUrl: String { get }
    var decentralizedDomain: String { get }
    var defaultCurrency: CurrencyItemData { get }
    var soranetExplorerTemplate: String { get }

    var supportEmail: String { get }
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var version: String { get }
    var invitationHostURL: URL { get }
    var opensourceURL: URL { get }
    var telegramURL: URL { get }
    var siteURL: URL { get }
    var faqURL: URL { get }
    var pendingFailureDelay: TimeInterval { get }
    var combinedTransfersHandlingDelay: TimeInterval { get }
    var polkaswapURL: URL { get }
    var rewardsURL: URL { get }
    var parliamentURL: URL { get }
    var phishingListURL: URL { get }
    var shareURL: URL { get }
    var subqueryUrl: URL { get }
    var addressType: SNAddressType { get }
    var defaultChainNodes: Set<ChainNodeModel> { get }

    var assetListURL: URL? { get }
    var commonTypesURL: URL? { get }
    var chainListURL: URL? { get }
    var nodesURL: URL? { get }
}

private struct InternalConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case projectDecentralizedId = "projectDID"
        case notificationDecentralizedId = "notificationDID"
        case notificationOptions = "notificationOptions"
        case walletDecentralizedId = "walletDID"
        case didResolverUrl = "didResolverUrl"
        case decentralizedDomain = "decentralizedDomain"
        case defaultCurrency = "currency"
        case soranetExplorerTemplate = "soranetExplorer"
        case ethereumExplorerTemplate = "ethereumExplorer"
    }

    var projectDecentralizedId: String
    var notificationDecentralizedId: String
    var notificationOptions: UInt8
    var walletDecentralizedId: String
    var didResolverUrl: String
    var decentralizedDomain: String
    var defaultCurrency: CurrencyItemData
    var soranetExplorerTemplate: String
    var ethereumExplorerTemplate: String
}

enum ConfigError: Error {
    case ethConfigFailed
}

extension ConfigError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        return ErrorContent(title: R.string.localizable.connectionErrorTitle(),
                            message: R.string.localizable.ethereumConfigUnavailable())
    }
}

final class ApplicationConfig {
    static let shared: ApplicationConfig! = ApplicationConfig()

    static var logger: LoggerProtocol = Logger.shared

    private struct Constants {
        static let infoConfigKey = "AppConfigName"
        static let configFilename = "appConfig"
        static let configFileExt = "plist"
    }

    private var config: InternalConfig

    private convenience init?() {
        guard let configName = Bundle.main.object(forInfoDictionaryKey: Constants.infoConfigKey) as? String else {
            ApplicationConfig.logger.error("""
                Please, provide configuration in info.plist under
                \(Constants.infoConfigKey) key
                """)

            return nil
        }

        self.init(configName: configName)
    }

    init?(configName: String) {
        guard let configURL = Bundle.main
            .url(forResource: Constants.configFilename, withExtension: Constants.configFileExt) else {
                ApplicationConfig.logger
                    .error("Please, check that \(Constants.configFilename).\(Constants.configFileExt) exists")
                return nil
        }

        guard let configData = try? Data(contentsOf: configURL) else {
            ApplicationConfig.logger.error("Can't read config data at url \(configURL.absoluteString)")
            return nil
        }

        guard let root = try? PropertyListDecoder().decode([String: InternalConfig].self, from: configData) else {
            ApplicationConfig.logger.error("Can't parse config data at url \(configURL.absoluteString)")
            return nil
        }

        guard let config = root[configName] else {
            ApplicationConfig.logger.error("Can't find configuration with name \(configName)")
            return nil
        }

        self.config = config
    }
}

extension ApplicationConfig: ApplicationConfigProtocol {

    var projectDecentralizedId: String {
        config.projectDecentralizedId
    }

    var notificationDecentralizedId: String {
        config.notificationDecentralizedId
    }

    var notificationOptions: UInt8 {
        config.notificationOptions
    }

    var walletDecentralizedId: String {
        config.walletDecentralizedId
    }

    var didResolverUrl: String {
        config.didResolverUrl
    }

    var decentralizedDomain: String {
        config.decentralizedDomain
    }

    var defaultCurrency: CurrencyItemData {
        config.defaultCurrency
    }

    var soranetExplorerTemplate: String {
        config.soranetExplorerTemplate
    }

    var supportEmail: String {
        "support@sora.org"
    }

    var termsURL: URL {
        URL(string: "https://sora.org/terms")!
    }

    var privacyPolicyURL: URL {
        URL(string: "https://sora.org/privacy")!
    }
    
    var twitterURL: URL {
        URL(string: "https://twitter.com/sora_xor")!
    }
    
    var youtubeURL: URL {
        URL(string: "https://youtube.com/sora_xor")!
    }
    
    var instagramURL: URL {
        URL(string: "https://instagram.com/sora_xor")!
    }
    
    var mediumURL: URL {
        URL(string: "https://medium.com/sora-xor")!
    }
    
    var wikiURL: URL {
        URL(string: "https://wiki.sora.org")!
    }
    
    var announcementsURL: URL {
        URL(string: "https://t.me/sora_announcements")!
    }
    
    var supportURL: URL {
        URL(string: "https://t.me/sorahappiness")!
    }
    
    //swiftlint:disable force_cast
    var version: String {
        let bundle = Bundle(for: ApplicationConfig.self)

        let mainVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as! String
        let buildNumber = bundle.infoDictionary?["CFBundleVersion"] as! String

        return "\(mainVersion).\(buildNumber)"
    }
    //swiftlint:enable force_cast

    var invitationHostURL: URL {
        URL(string: "https://sora-xor.github.io/sora-join-page/")!
    }

    var telegramURL: URL {
        URL(string: "https://t.me/sora_xor")!
    }

    var siteURL: URL {
        URL(string: "https://sora.org")!
    }

    var opensourceURL: URL {
        URL(string: "https://github.com/sora-xor/Sora-iOS")!
    }

    var faqURL: URL {
        URL(string: "https://wiki.sora.org/guides/sora-faq")!
    }

    var shareURL: URL {
        URL(string: "https://sora.org/#rec229853503")!
    }

    var combinedTransfersHandlingDelay: TimeInterval { 1800 }

    var polkaswapURL: URL {
        URL(string: "https://polkaswap.io")!
    }

    var parliamentURL: URL {
        URL(string:"https://medium.com/sora-xor/the-sora-parliament-af8184dae384")!
    }

    var rewardsURL: URL {
        URL(string: "https://sora-xor.medium.com/sora-validator-rewards-419320e22df8")!
    }
    var pendingFailureDelay: TimeInterval { 86400 }

    var phishingListURL: URL {
        return URL(string: "https://polkadot.js.org/phishing/address.json")!
    }

    var addressType: SNAddressType {
        return SNAddressType(SettingsManager.shared.externalAddressPrefix ?? 69)
    }

    var defaultChainNodes: Set<ChainNodeModel> {
    #if F_RELEASE
        return [
            ChainNodeModel(url: URL(string: "wss://ws.mof.sora.org")!, name: "Sora", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.mof2.sora.org")!, name: "Sora", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.mof3.sora.org")!, name: "Sora", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://sora.api.onfinality.io/public-ws")!, name: "Sora onFinality", apikey: nil),
        ]

    #elseif F_STAGING || F_TEST
        return [
            ChainNodeModel(url: URL(string: "wss://ws.framenode-1.s1.stg1.sora2.soramitsu.co.jp")!, name: "Soralution", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.framenode-2.s1.stg1.sora2.soramitsu.co.jp")!, name: "Soralution", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.framenode-3.s2.stg1.sora2.soramitsu.co.jp")!, name: "Soralution", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.framenode-4.s2.stg1.sora2.soramitsu.co.jp")!, name: "Soralution", apikey: nil),
        ]
    #else
        return [
            ChainNodeModel(url: URL(string: "wss://ws.framenode-1.r0.dev.sora2.soramitsu.co.jp")!, name: "framenode-1.r0.dev", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.framenode-2.r0.dev.sora2.soramitsu.co.jp")!, name: "framenode-2.r0.dev", apikey: nil),
            ChainNodeModel(url: URL(string: "wss://ws.framenode-3.r0.dev.sora2.soramitsu.co.jp")!, name: "framenode-3.r0.dev", apikey: nil),
        ]

    #endif
    }

    var subqueryUrl: URL {
        #if F_RELEASE
            return URL(string: "https://subquery.q1.sora2.soramitsu.co.jp")!
        #elseif F_STAGING || F_TEST
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-staging__c29yY")!
        #else
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-dev")!
        #endif
    }
    
    var isDisclamerShown: Bool {
        return UserDefaults.standard.bool(forKey: "isDisclamerShown")
    }
    
    var assetListURL: URL? {
        return URL(string: "https://whitelist.polkaswap2.io/whitelist.json")!
    }

    var caseName: String {
    #if F_RELEASE
    return "0"
    #else
    return "2"
    #endif
    }

    var nodesURL: URL? {
        var stand = ""

        #if F_RELEASE
        stand = "prod"
        #elseif F_STAGING || F_TEST
        stand = "stage"
        #else
        stand = "dev"
        #endif

        return GitHubUrl.url(suffix: "sora2_config.json",
                             branch: "sora2-substrate-js-library/metadata14/packages/types/src/metadata/\(stand)/")
    }

    var commonTypesURL: URL? {
        GitHubUrl.url(suffix: "types_scalecodec_mobile.json", branch: "sora2-substrate-js-library/metadata14ios/packages/types/src/metadata/\(GitHubUrl.repoPrefix)/")
    }

    var chainListURL: URL? {
        return GitHubUrl.url(suffix: "")
    }
    
    var backupedAccountAddresses: [String] {
        get {
            return UserDefaults.standard.array(forKey: "backupedAccountAddresses") as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "backupedAccountAddresses")
        }
    }
    
    var enabledCardIdentifiers: [Int] {
        get {
            let defaultIdentifiers = Cards.allCases.filter { $0.defaultState != .disabled }.map { $0.id }
            return UserDefaults.standard.array(forKey: "enabledCardIdentifiers") as? [Int] ?? defaultIdentifiers
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "enabledCardIdentifiers")
        }
    }
    
    var commonConfigUrl: String {
        #if F_RELEASE
        return "https://config.polkaswap2.io/prod/common.json"
        #elseif F_STAGING || F_TEST
        return "https://config.polkaswap2.io/stage/common.json"
        #else
        return "https://config.polkaswap2.io/dev/common.json"
        #endif
    }
    
    var mobileConfigUrl: String {
        #if F_RELEASE
        return "https://config.polkaswap2.io/prod/mobile.json"
        #elseif F_STAGING || F_TEST
        return "https://config.polkaswap2.io/stage/mobile.json"
        #else
        return "https://config.polkaswap2.io/dev/mobile.json"
        #endif
    }
}
//swiftlint:enable line_length


private enum GitHubUrl {

    static var repoPrefix: String {
        #if F_RELEASE
            return "prod"
        #elseif F_STAGING
            return "stage"
        #elseif F_TEST
            return "test"
        #else
            return "dev"
        #endif
    }

    private static var baseUrl: URL? {
        URL(string: "https://raw.githubusercontent.com/sora-xor/")
    }

    private static let defaultBranch = repoPrefix

    static func url(suffix: String, branch: String = defaultBranch) -> URL? {
        baseUrl?.appendingPathComponent(branch).appendingPathComponent(suffix)
    }
}

