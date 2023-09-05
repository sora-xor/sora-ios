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

import FearlessUtils
import BigInt
import Foundation

class SwapAmount: Codable {
    var desired: BigUInt
    var slip: BigUInt
    let type: SwapVariant

    enum CodingKeysIn: String, CodingKey {
        case desired = "desiredAmountIn"
        case slip = "minAmountOut"
    }
    enum CodingKeysOut: String, CodingKey {
        case desired = "desiredAmountOut"
        case slip = "maxAmountIn"
    }

    init(type: SwapVariant, desired: BigUInt, slip: BigUInt) {
        self.desired = desired
        self.slip = slip
        self.type = type
    }

    required public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeysIn.self),
           !container.allKeys.isEmpty {
            let slip = try container.decode(String.self, forKey: CodingKeysIn.slip)
            let desired = try container.decode(String.self, forKey: CodingKeysIn.desired)
            self.slip = BigUInt(slip) ?? 0
            self.desired = BigUInt(desired) ?? 0
            type = .desiredInput
        } else
        if let container = try? decoder.container(keyedBy: CodingKeysOut.self),
           !container.allKeys.isEmpty {
            let desired = try container.decode(String.self, forKey: CodingKeysOut.slip)
            let slip = try container.decode(String.self, forKey: CodingKeysOut.desired)
            self.slip = BigUInt(slip) ?? 0
            self.desired = BigUInt(desired) ?? 0
            type = .desiredOutput
        } else {
            let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                debugDescription: "Invalid CodingKey")
            throw DecodingError.typeMismatch(SwapAmount.self, context)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch type {
            //please, mind that we encode .description, because metadata requires string, and @stringCodable somehow fails
        case .desiredOutput:
            var container = encoder.container(keyedBy: CodingKeysOut.self)
            try container.encode(desired.description, forKey: .desired)
            try container.encode(slip.description, forKey: .slip)
        case .desiredInput:
            var container = encoder.container(keyedBy: CodingKeysIn.self)
            try container.encode(desired.description, forKey: .desired)
            try container.encode(slip.description, forKey: .slip)
        }
    }
}

enum SwapVariant: String, Codable {
    case desiredInput = "WithDesiredInput"
    case desiredOutput = "WithDesiredOutput"
    
    var title: String {
        switch self {
        case .desiredInput: return R.string.localizable.polkaswapMinimumReceived(preferredLanguages: .currentLocale)
        case .desiredOutput: return R.string.localizable.polkaswapMaximumSold(preferredLanguages: .currentLocale)
        }
    }
    
    var message: String {
        switch self {
        case .desiredInput: return R.string.localizable.polkaswapMinimumReceivedInfo(preferredLanguages: .currentLocale)
        case .desiredOutput: return R.string.localizable.polkaswapMaximumSoldInfo(preferredLanguages: .currentLocale)
        }
    }
}

struct SwapCall: Codable {
    let dexId: String
    var inputAssetId: AssetId
    var outputAssetId: AssetId

    var amount: [SwapVariant: SwapAmount]
    let liquiditySourceType: [[String?]] //TBD liquiditySourceType.codable
    let filterMode: FilterModeType

    enum CodingKeys: String, CodingKey {
        case dexId = "dexId"
        case inputAssetId = "inputAssetId"
        case outputAssetId = "outputAssetId"
        case amount = "swapAmount"
        case liquiditySourceType = "selectedSourceTypes"
        case filterMode = "filterMode"
    }

}

struct FilterModeType: Codable {
    var name: String
    var value: UInt?

    public init(wrappedName: String, wrappedValue: UInt?) {
        self.name = wrappedName
        self.value = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let dict = try container.decode([String?].self)
            let val1 = dict.first ?? "-"
            let val2 = dict.last ??  nil
            name = val1 ?? "-"

            if let value = val2 {
                self.value = UInt(value)
            }
        } catch {
            let dict = try container.decode(JSON.self)
            name = dict.arrayValue?.first?.stringValue ?? "-"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let value: [String?] = [name, nil]
        try container.encode(value)
    }
}
