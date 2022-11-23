/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
}
