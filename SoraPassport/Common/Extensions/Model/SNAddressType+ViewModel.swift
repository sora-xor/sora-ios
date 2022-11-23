/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

extension SNAddressType {
    func titleForLocale(_ locale: Locale) -> String {
        return "Sora"
    }
//
    var icon: UIImage? {
        return R.image.iconSora()
    }

//    static var supported: [SNAddressType] {
//        [/*.kusamaMain, .polkadotMain, */.genericSubstrate, .soraMain]
//    }
}
