/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

extension Locale {
    var rLanguages: [String]? {
        return [identifier]
    }
}

extension Array where Element == String {
    static var currentLocale: [String]? {
        LocalizationManager.shared.selectedLocale.rLanguages
    }
}
