/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
@testable import SoraPassport

func createRandomLanguageList() -> [Language] {
    return Locale.isoLanguageCodes.map { code in
        return Language(code: code)
    }
}
