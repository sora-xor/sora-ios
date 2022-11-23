import UIKit

enum AboutOption {
    // with URL addresses
    case terms
    case privacy
    case website
    case telegram
    case twitter
    case youtube
    case instagram
    case medium
    case wiki
    case announcements
    case support

    /// Keep version as associated values
    case opensource(version: String)

    /// Keep email as associated values
    case writeUs(toEmail: String)
}

extension AboutOption {

    func iconImage() -> UIImage? {
        switch self {
        case .website:          return R.image.about.website()
        case .opensource:       return R.image.about.github()
        case .telegram:         return R.image.about.telegram()
        case .writeUs:          return R.image.about.email()
        case .terms:            return R.image.about.check()
        case .privacy:          return R.image.about.check()
        case .twitter:          return R.image.about.twitter()
        case .youtube:          return R.image.about.youtube()
        case .instagram:        return R.image.about.instagram()
        case .medium:           return R.image.about.medium()
        case .wiki:             return R.image.about.wiki()
        case .announcements:    return R.image.about.announcements()
        case .support:          return R.image.about.support()
        }
    }

    func title(for locale: Locale) -> String {
        let languages = locale.rLanguages
        switch self {
        case .website:                  return R.string.localizable.aboutWebsite(preferredLanguages: languages)
        case .telegram:                 return R.string.localizable.aboutTelegram(preferredLanguages: languages)
        case .writeUs:                  return R.string.localizable.aboutContactUs(preferredLanguages: languages)
        case .terms:                    return R.string.localizable.aboutTerms(preferredLanguages: languages)
        case .privacy:                  return R.string.localizable.aboutPrivacy(preferredLanguages: languages)
        case .twitter:                  return R.string.localizable.aboutTwitter(preferredLanguages: languages)
        case .youtube:                  return R.string.localizable.aboutYoutube(preferredLanguages: languages)
        case .instagram:                return R.string.localizable.aboutInstagram(preferredLanguages: languages)
        case .medium:                   return R.string.localizable.aboutMedium(preferredLanguages: languages)
        case .wiki:                     return R.string.localizable.aboutWiki(preferredLanguages: languages)
        case .announcements:            return R.string.localizable.aboutAnnouncements(preferredLanguages: languages)
        case .support:                  return R.string.localizable.aboutAskSupport(preferredLanguages: languages)
        case .opensource(let version):  return R.string.localizable.aboutSourceCode(preferredLanguages: languages) + " (v\(version))"

        }
    }

    func address() -> URL? {
        switch self {
        case .website:          return ApplicationConfig.shared.siteURL
        case .opensource:       return ApplicationConfig.shared.opensourceURL
        case .telegram:         return ApplicationConfig.shared.telegramURL
        case .terms:            return ApplicationConfig.shared.termsURL
        case .privacy:          return ApplicationConfig.shared.privacyPolicyURL
        case .twitter:          return ApplicationConfig.shared.twitterURL
        case .youtube:          return ApplicationConfig.shared.youtubeURL
        case .instagram:        return ApplicationConfig.shared.instagramURL
        case .medium:           return ApplicationConfig.shared.mediumURL
        case .wiki:             return ApplicationConfig.shared.wikiURL
        case .announcements:    return ApplicationConfig.shared.announcementsURL
        case .support:          return ApplicationConfig.shared.supportURL
        case .writeUs:          return nil
        }
    }
}
