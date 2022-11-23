/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum ProfileOptionsHeader: String, CaseIterable {
    case accountSettings
    case appSettings
    case other
}

extension ProfileOptionsHeader {
    
    var options: [ProfileOption] {
        switch self {
        case .accountSettings:
            return [.account, .accountName, .passphrase, .logout]
        case .appSettings:
            return [.nodes, .changePin, .biometry, .language]
        case .other:
            return [.friends, .faq, .about, .disclaimer]
        }
    }
    
    func title(for locale: Locale) -> String {
        switch self {
        case .accountSettings:      return R.string.localizable.settingsHeaderAccount(preferredLanguages: locale.rLanguages)
        case .appSettings: return R.string.localizable.settingsHeaderApp(preferredLanguages: locale.rLanguages)
        case .other: return R.string.localizable.settingsHeaderOther(preferredLanguages: locale.rLanguages)
        }
    }
    
}
