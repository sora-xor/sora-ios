import Foundation

enum AccountImportSource: CaseIterable {
    case mnemonic
    case seed
    case keystore
}

extension AccountImportSource: SourceType {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .mnemonic: return R.string.localizable.commonPassphraseTitle(preferredLanguages: locale.rLanguages)
        case .seed: return R.string.localizable.commonRawSeed(preferredLanguages: locale.rLanguages)
        case .keystore: return "JSON" // for the future
        }
    }

    var descriptionText: String? {
        return nil
    }
    
    var navigationTitle: String {
        switch self {
        case .mnemonic: return R.string.localizable.onboardingEnterPassphrase(preferredLanguages: .currentLocale)
        case .seed: return R.string.localizable.onboardingEnterSeed(preferredLanguages: .currentLocale)
        case .keystore: return "JSON" // for the future
        }
    }
    
    var containerTitle: String {
        switch self {
        case .mnemonic: return R.string.localizable.recoveryEnterPassphraseTitle(preferredLanguages: .currentLocale)
        case .seed: return R.string.localizable.recoveryEnterSeedTitle(preferredLanguages: .currentLocale)
        case .keystore: return "JSON" // for the future
        }
    }
}
