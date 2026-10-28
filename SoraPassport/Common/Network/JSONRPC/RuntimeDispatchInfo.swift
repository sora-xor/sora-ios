// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import BigInt

struct RuntimeDispatchInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case dispatchClass = "class"
        case fee = "partialFee"
        case weight
    }

    let dispatchClass: String
    let fee: String
    let weight: UInt64
}

struct FeeDetails: Codable {
    let baseFee: BigUInt
    let lenFee: BigUInt
    let adjustedWeightFee: BigUInt

    init(
        baseFee: BigUInt,
        lenFee: BigUInt,
        adjustedWeightFee: BigUInt
    ) {
        self.baseFee = baseFee
        self.lenFee = lenFee
        self.adjustedWeightFee = adjustedWeightFee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let baseFeeHex = try container.decode(String.self, forKey: .baseFee)
        let lenFeeHex = try container.decode(String.self, forKey: .lenFee)
        let adjustedWeightFeeHex = try container.decode(String.self, forKey: .adjustedWeightFee)

        baseFee = BigUInt.fromHexString(baseFeeHex) ?? BigUInt.zero
        lenFee = BigUInt.fromHexString(lenFeeHex) ?? BigUInt.zero
        adjustedWeightFee = BigUInt.fromHexString(adjustedWeightFeeHex) ?? BigUInt.zero
    }
}

struct InclusionFeeInfo: Codable {
    let inclusionFee: FeeDetails

    var fee: String {
        "\(inclusionFee.baseFee + inclusionFee.lenFee + inclusionFee.adjustedWeightFee)"
    }
}
