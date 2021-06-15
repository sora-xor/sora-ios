/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils

struct SlashingSpans: Decodable {
    @StringCodable var lastNonzeroSlash: UInt32
}
