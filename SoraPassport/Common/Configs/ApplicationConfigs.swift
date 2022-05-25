import Foundation
import os

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
    var parliamentURL: URL  { get }
    var phishingListURL: URL { get }
    var shareURL: URL { get }
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
        URL(string: "https://wiki.sora.org/sora-faq")!
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
}
