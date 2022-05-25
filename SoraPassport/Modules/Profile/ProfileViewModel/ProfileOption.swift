import UIKit

enum ProfileOption: UInt, CaseIterable {
    case account
    case friends    // accessorible
    case passphrase
    case changePin
    case biometry   // switchable
    case language   // accessorible
    case faq
    case about
    case disclaimer
    case logout
}

extension ProfileOption {

    func iconImage() -> UIImage? {
        switch self {
        case .account:      return R.image.profile.account()
        case .friends:      return R.image.profile.friends()
        case .passphrase:   return R.image.profile.passphrases()
        case .changePin:    return R.image.profile.changePin()
        case .biometry:     return R.image.profile.biometry()
        case .language:     return R.image.profile.language()
        case .faq:          return R.image.profile.faq()
        case .about:        return R.image.profile.about()
        case .disclaimer:   return R.image.profile.disclaimer()
        case .logout:       return R.image.profile.logout()
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .account:      return R.string.localizable.personalInfoUsernameV1(preferredLanguages: locale.rLanguages)
        case .friends:      return R.string.localizable.tabbarFriendsTitle(preferredLanguages: locale.rLanguages)
        case .passphrase:   return R.string.localizable.profilePassphraseTitleV1(preferredLanguages: locale.rLanguages)
        case .changePin:    return R.string.localizable.profileChangePinTitle(preferredLanguages: locale.rLanguages)
        case .biometry:     return R.string.localizable.profileBiometryTitle(preferredLanguages: locale.rLanguages)
        case .language:     return R.string.localizable.profileLanguageTitle(preferredLanguages: locale.rLanguages)
        case .faq:          return R.string.localizable.profileFaqTitle(preferredLanguages: locale.rLanguages)
        case .about:        return R.string.localizable.profileAboutTitle(preferredLanguages: locale.rLanguages)
        case .disclaimer:   return R.string.localizable.polkaswapInfoTitle(preferredLanguages: locale.rLanguages)
        case .logout:       return R.string.localizable.profileLogoutTitle(preferredLanguages: locale.rLanguages)
        }
    }
}
