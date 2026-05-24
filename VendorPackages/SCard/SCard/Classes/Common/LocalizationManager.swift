import Foundation

typealias LocalizationChangeClosure = (String, String) -> Void

protocol LocalizationManagerProtocol {
    var selectedLocalization: String { get set }

    var availableLocalizations: [String] { get }

    func addObserver(with owner: AnyObject,
                     queue: DispatchQueue?,
                     closure: @escaping LocalizationChangeClosure)

    func removeObserver(by owner: AnyObject)
}

extension LocalizationManagerProtocol {
    var selectedLocale: Locale {
        return Locale(identifier: selectedLocalization)
    }

    func addObserver(with owner: AnyObject, closure: @escaping LocalizationChangeClosure) {
        addObserver(with: owner, queue: nil, closure: closure)
    }
}

final class LocalizationManager: LocalizationManagerProtocol {
    public struct ObserverWrapper {
        public weak var owner: AnyObject?
        public let closure: LocalizationChangeClosure
        public let queue: DispatchQueue?
    }

    public private(set) var settings: SettingsManagerProtocol?
    public private(set) var settingsKey: String?

    public private(set) var observers: [ObserverWrapper] = []

    public var selectedLocalization: String {
        didSet {
            if oldValue != selectedLocalization {

                if let settings = settings, let settingsKey = settingsKey {
                    settings.set(value: selectedLocalization, for: settingsKey)
                }

                notify(oldLocalization: oldValue, newLocalization: selectedLocalization)
            }
        }
    }

    public var availableLocalizations: [String]

    public init(settings: SettingsManagerProtocol,
                key: String,
                preferredLanguages: [String] = Locale.preferredLanguages,
                availableLocalizations: [String] = Bundle.main.localizations,
                defaultLocalization: String = "en") {
        self.settings = settings
        self.settingsKey = key
        self.availableLocalizations = availableLocalizations

        if let localization = settings.string(for: key) {
            self.selectedLocalization = localization
        } else {
            let localization = LocalizationManager
                .determineSuitableLocalization(for: preferredLanguages,
                                               availableLocalizations: availableLocalizations) ?? defaultLocalization

            self.settings?.set(value: localization, for: key)
            self.selectedLocalization = localization
        }
    }

    public init?(localization: String, availableLocalizations: [String] = Bundle.main.localizations) {
        let components = Locale.components(fromIdentifier: localization)

        guard components[NSLocale.Key.languageCode.rawValue] != nil else {
            return nil
        }

        self.selectedLocalization = localization
        self.availableLocalizations = availableLocalizations
    }

    public func addObserver(with owner: AnyObject,
                     queue: DispatchQueue?,
                     closure: @escaping LocalizationChangeClosure) {
        observers.append(ObserverWrapper(owner: owner,
                                         closure: closure,
                                         queue: queue))

        observers = observers.filter { $0.owner !== nil }
    }

    public func removeObserver(by owner: AnyObject) {
        observers = observers.filter { $0.owner !== owner && $0.owner !== nil}
    }

    private func notify(oldLocalization: String, newLocalization: String) {
        observers = observers.filter { $0.owner !== nil }

        observers.forEach { wrapper in
            if wrapper.owner != nil {
                if let queue = wrapper.queue {
                    queue.async {
                        wrapper.closure(oldLocalization, newLocalization)
                    }
                } else {
                    wrapper.closure(oldLocalization, newLocalization)
                }
            }
        }
    }

    private static func determineSuitableLocalization(for preferredLanguages: [String],
                                                      availableLocalizations: [String]) -> String? {

        for preferredLanguage in preferredLanguages {
            if availableLocalizations.contains(preferredLanguage) {
                return preferredLanguage
            }

            let preferredComponent = Locale.components(fromIdentifier: preferredLanguage)

            guard let language = preferredComponent[NSLocale.Key.languageCode.rawValue] else {
                continue
            }

            for availableLocalization in availableLocalizations {
                let availableComponents = Locale.components(fromIdentifier: availableLocalization)

                if language == availableComponents[NSLocale.Key.languageCode.rawValue] {
                    return availableLocalization
                }
            }
        }

        return nil
    }
}

extension LocalizationManagerProtocol {
    var preferredLocalizations: [String]? {
        return [selectedLocalization]
    }

    var selectedLanguage: Language {
        return Language(code: selectedLocalization)
    }
}

extension LocalizationManager {
    static let shared = LocalizationManager(settings: SettingsManager.shared,
                                            key: SettingsKey.selectedLocalization.rawValue)
}

struct Language: Codable {
    let code: String
}

extension Language {
    func title(in locale: Locale) -> String? {
        let components = Locale.components(fromIdentifier: code)

        if let language = components[NSLocale.Key.languageCode.rawValue] {
            return locale.localizedString(forLanguageCode: language)
        } else {
            return nil
        }
    }

    func region(in locale: Locale) -> String? {
        let components = Locale.components(fromIdentifier: code)

        if let regionCode = components[NSLocale.Key.countryCode.rawValue] {
            return locale.localizedString(forRegionCode: regionCode)
        } else {
            return nil
        }
    }
}

enum SettingsKey: String {
    case decentralizedId
    case publicKeyId
    case biometryEnabled
    case disclaimerHidden
    case invitationCode
    case isCheckedInvitation
    case selectedLocalization
    case lastStreamEventId
    case streamToken
    case selectedAccount
    case hasMigrated
    case externalGenesis
    case externalExistentialDeposit
    case externalPrefix
    case assetList
    case inputBlockDate
    case failInputPinCount
    case lastSuccessfulUrl
}
