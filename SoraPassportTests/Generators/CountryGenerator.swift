/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
@testable import SoraPassport

func createRandomCountry() -> Country {
    return createRandomCountry(with: [true, false].randomElement()!)
}

func createRandomCountry(with supported: Bool) -> Country {
    let isoCode = String((1..<10000).randomElement()!)
    let dialCode = "+\(String((1..<10).randomElement()!))"
    let country = ["Japan", "USA", "Russia", "Egypt"].randomElement()!

    return Country(identitfier: isoCode, name: country, dialCode: dialCode, supported: supported)
}
