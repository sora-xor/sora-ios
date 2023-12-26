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
import SSFUtils
import BigInt

struct SoraTransferCall: Codable {
    var receiver: Data
    @StringCodable var amount: BigUInt
    var assetId: AssetId

    enum CodingKeys: String, CodingKey {
        case receiver = "to"
        case assetId = "assetId"
        case amount = "amount"
    }
}

public enum SoraAddress: Equatable {
    case address32(_ value: Data)
}

extension SoraAddress: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let data = try container.decode(Data.self)
        self = .address32(data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .address32(let value):
            try container.encode(value)
        }
    }
}

extension MultiAddress {
    var data: Data {
        switch self {
        case .accoundId(let value):
            return value
        case .accountTo(let value):
            return value
        case .accountIndex(let value):
            return value.serialize()
        case .raw(let value):
            return value
        case .address32(let value):
            return value
        case .address20(let value):
            return value
        }
    }
}

struct getPools {
    
    var two: AssetId
    var one: AssetId
}

struct GetPools: Codable {
    var targetAsset: AssetId
    var rewardAsset: AssetId
}

struct AssetId: Codable {
    @ArrayCodable var value: String

    public init(wrappedValue: String) {
        self.value = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: Data].self)

        value = dict["code"]?.toHex(includePrefix: true) ?? "-"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let bytes = try? Data(hexStringSSF: value).map({ StringScaleMapper(value: $0) }) else {
            let context = EncodingError.Context(codingPath: container.codingPath,
                                                debugDescription: "Invalid encoding")
            throw EncodingError.invalidValue(value, context)
        }
        try container.encode(["code": bytes])
    }
}


@propertyWrapper
public struct ArrayCodable: Codable, Equatable {
    public var wrappedValue: String

    public init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringScaleMapper<UInt8>].self)
        let value = byteArray.reduce("0x") { $0 + String(format: "%02x", $1.value) }

        wrappedValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        guard let bytes = try? Data(hexStringSSF: wrappedValue).map({ StringScaleMapper(value: $0) }) else {
            let context = EncodingError.Context(codingPath: container.codingPath,
                                                debugDescription: "Invalid encoding")
            throw EncodingError.invalidValue(wrappedValue, context)
        }

        try container.encode(bytes)
    }
}
