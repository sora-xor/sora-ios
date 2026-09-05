// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
