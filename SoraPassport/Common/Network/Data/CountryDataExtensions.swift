/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension CountryData {
    var countries: [Country] {
        return topics.map { (key, value) in
            return Country(identitfier: key,
                           name: value.name,
                           dialCode: value.dialCode,
                           supported: value.csp == .supported)
        }
    }
}
