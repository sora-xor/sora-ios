/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils

extension ScaleEncodable {
    func scaleEncoded() throws -> Data {
        let scaleEncoder = ScaleEncoder()
        try encode(scaleEncoder: scaleEncoder)
        return scaleEncoder.encode()
    }
}
