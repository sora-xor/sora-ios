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
    private enum CodingKeys: String, CodingKey {
        case baseFee
        case lenFee
        case adjustedWeightFee
    }

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

        baseFee = try Self.decodeHexQuantity(
            forKey: .baseFee,
            from: container
        )
        lenFee = try Self.decodeHexQuantity(
            forKey: .lenFee,
            from: container
        )
        adjustedWeightFee = try Self.decodeHexQuantity(
            forKey: .adjustedWeightFee,
            from: container
        )
    }

    /// Runtime fee components are SCALE RPC quantities, not user-facing
    /// decimal strings. Reject an absent prefix, an empty payload, or any
    /// non-hexadecimal scalar so a malformed component can never silently
    /// weaken the fee used for a signing decision.
    private static func decodeHexQuantity(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> BigUInt {
        let rawValue = try container.decode(String.self, forKey: key)
        guard rawValue.hasPrefix("0x") else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Runtime fee quantity has no hexadecimal prefix"
            )
        }

        let digits = rawValue.dropFirst(2)
        guard !digits.isEmpty,
              digits.unicodeScalars.allSatisfy({ scalar in
                  (48 ... 57).contains(scalar.value)
                      || (65 ... 70).contains(scalar.value)
                      || (97 ... 102).contains(scalar.value)
              }),
              let value = BigUInt(String(digits), radix: 16) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Runtime fee quantity is not hexadecimal"
            )
        }
        return value
    }
}

struct InclusionFeeInfo: Codable {
    let inclusionFee: FeeDetails

    var fee: String {
        "\(inclusionFee.baseFee + inclusionFee.lenFee + inclusionFee.adjustedWeightFee)"
    }
}
