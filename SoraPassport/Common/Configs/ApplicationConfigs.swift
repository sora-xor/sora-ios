/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import os
import SoraCrypto

protocol ApplicationConfigProtocol {
    var projectDecentralizedId: String { get }
    var notificationDecentralizedId: String { get }
    var notificationOptions: UInt8 { get }
    var walletDecentralizedId: String { get }
    var didResolverUrl: String { get }
    var decentralizedDomain: String { get }
    var defaultProjectUnit: ServiceUnit { get }
    var defaultNotificationUnit: ServiceUnit { get }
    var defaultWalletUnit: ServiceUnit { get }
    var defaultSoranetUnit: ServiceUnit { get }
    var defaultStreamUnit: ServiceUnit { get }
    var defaultCurrency: CurrencyItemData { get }
    var soranetExplorerTemplate: String { get }
    var ethereumExplorerTemplate: String { get }

    var supportEmail: String { get }
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var version: String { get }
    var invitationHostURL: URL { get }
    var opensourceURL: URL { get }
    var faqURL: URL { get }
    var ethereumMasterContract: Data { get }
    var ethereumNodeUrl: URL { get }
    var ethereumNodeAuth: String { get }
    var ethereumChainId: EthereumChain { get }
    var ethereumPollingTimeInterval: TimeInterval { get }
    var pendingFailureDelay: TimeInterval { get }
    var combinedTransfersHandlingDelay: TimeInterval { get }
    func applyExternalConfig(_ config: EthNodeData)
}

private struct InternalConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case projectDecentralizedId = "projectDID"
        case notificationDecentralizedId = "notificationDID"
        case notificationOptions = "notificationOptions"
        case walletDecentralizedId = "walletDID"
        case didResolverUrl = "didResolverUrl"
        case defaultProjectUnit = "projectUnit"
        case defaultNotificationUnit = "notificationUnit"
        case defaultWalletUnit = "walletUnit"
        case defaultSoranetUnit = "soranetUnit"
        case defaultStreamUnit = "streamUnit"
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
    var defaultProjectUnit: ServiceUnit
    var defaultNotificationUnit: ServiceUnit
    var defaultWalletUnit: ServiceUnit
    var defaultSoranetUnit: ServiceUnit
    var defaultStreamUnit: ServiceUnit
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

    var extEthereumMasterContract: String?
    var extEthereumNodeUrl: String?
    var extEthereumNodeAuth: String?
    var extEtherscan: String?
}

extension ApplicationConfig: ApplicationConfigProtocol {
    func applyExternalConfig(_ config: EthNodeData) {
        extEthereumNodeUrl = config.ethereumURL
        extEthereumMasterContract = try? Data(hexString: config.masterContractAddress).toHex(includePrefix: false)
        extEthereumNodeAuth = config.ethereumUsername + ":" + config.ethereumPassword
        extEtherscan = config.etherscanBaseUrl + "tx/{hash}"
        ApplicationConfig.logger.info("external config applied, node: \(extEthereumNodeUrl ?? "no node??"), contract: \(config.masterContractAddress)" )
    }

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

    var defaultProjectUnit: ServiceUnit {
        config.defaultProjectUnit
    }

    var defaultNotificationUnit: ServiceUnit {
        config.defaultNotificationUnit
    }

    var defaultWalletUnit: ServiceUnit {
        config.defaultWalletUnit
    }

    var defaultSoranetUnit: ServiceUnit {
        config.defaultSoranetUnit
    }

    var defaultStreamUnit: ServiceUnit {
        config.defaultStreamUnit
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

    var ethereumExplorerTemplate: String {
        extEtherscan ?? config.ethereumExplorerTemplate
    }

    var supportEmail: String {
        "sora@soramitsu.co.jp"
    }

    var termsURL: URL {
        URL(string: "https://sora.org/terms")!
    }

    var privacyPolicyURL: URL {
        URL(string: "https://sora.org/privacy")!
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
        URL(string: "https://ref.sora.org")!
    }

    var opensourceURL: URL {
        URL(string: "https://github.com/sora-xor")!
    }

    var faqURL: URL {
        URL(string: "https://sora.org/faq")!
    }

    var ethereumMasterContract: Data {
        if let external = extEthereumMasterContract {
            return Data(hexString: external)!
        } else {
            return Data()
        }
    }

    var ethereumNodeAuth: String {
        if let external = extEthereumNodeAuth {
            return "Basic " + (external.data(using: .utf8)?.base64EncodedString())!
        }
        return ""
    }

    var ethereumNodeUrl: URL {
        if let external = extEthereumNodeUrl {
            return URL(string: external)!
        } else {
            return faqURL
        }
    }

    var ethereumChainId: EthereumChain {
        if let external = extEthereumNodeUrl {
            if external.contains("rinkeby") {
                return .rinkeby
            } else
            if external.contains("ropsten") {
                return .ropsten
            } else
            if external.contains("mainnet") {
                return .mainnet
            }
        }
        return .mainnet
    }

    var ethereumPollingTimeInterval: TimeInterval { 5.0 }

    var combinedTransfersHandlingDelay: TimeInterval { 1800 }

    var pendingFailureDelay: TimeInterval { 86400 }
}
