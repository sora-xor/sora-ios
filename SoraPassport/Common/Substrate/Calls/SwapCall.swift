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

import SSFUtils
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
            guard let exactSlip = BigUInt(slip), let exactDesired = BigUInt(desired) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Swap amounts must be unsigned integers"))
            }
            self.slip = exactSlip
            self.desired = exactDesired
            type = .desiredInput
        } else
        if let container = try? decoder.container(keyedBy: CodingKeysOut.self),
           !container.allKeys.isEmpty {
            let desired = try container.decode(String.self, forKey: CodingKeysOut.desired)
            let slip = try container.decode(String.self, forKey: CodingKeysOut.slip)
            guard let exactSlip = BigUInt(slip), let exactDesired = BigUInt(desired) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Swap amounts must be unsigned integers"))
            }
            self.slip = exactSlip
            self.desired = exactDesired
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
