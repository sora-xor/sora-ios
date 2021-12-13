/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

enum AboutOption {
    // with URL addresses
    case terms
    case privacy
    case website
    case telegram

    /// Keep version as associated values
    case opensource(version: String)

    /// Keep email as associated values
    case writeUs(toEmail: String)
}

extension AboutOption {

    func iconImage() -> UIImage? {
        switch self {
        case .website:      return R.image.about.website()
        case .opensource:   return R.image.about.github()
        case .telegram:     return R.image.about.telegram()
        case .writeUs:      return R.image.about.email()
        case .terms:        return R.image.about.document()
        case .privacy:      return R.image.about.document()
        }
    }

    func title(for locale: Locale) -> String {
        let languages = locale.rLanguages
        switch self {
        case .website:      return R.string.localizable.aboutWebsite(preferredLanguages: languages)
        case .telegram:     return R.string.localizable.aboutTelegram(preferredLanguages: languages)
        case .writeUs:      return R.string.localizable.aboutContactUs(preferredLanguages: languages)
        case .terms:        return R.string.localizable.aboutTerms(preferredLanguages: languages)
        case .privacy:      return R.string.localizable.aboutPrivacy(preferredLanguages: languages)
        case .opensource(let version):
            return R.string.localizable
                .aboutSourceCode(preferredLanguages: languages) + " (v\(version))"
        }
    }

    func address() -> URL? {
        switch self {
        case .website:      return ApplicationConfig.shared.siteURL
        case .opensource:   return ApplicationConfig.shared.opensourceURL
        case .telegram:     return ApplicationConfig.shared.telegramURL
        case .terms:        return ApplicationConfig.shared.termsURL
        case .privacy:      return ApplicationConfig.shared.privacyPolicyURL
        case .writeUs:      return nil
        }
    }
}
