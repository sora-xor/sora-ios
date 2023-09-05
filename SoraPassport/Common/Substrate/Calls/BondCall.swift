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
import FearlessUtils
import BigInt

struct BondCall: Codable {
    var controller: MultiAddress
    @StringCodable var value: BigUInt
    var payee: RewardDestinationArg
}

enum RewardDestinationArg {
    static let stakedField = "Staked"
    static let stashField = "Stash"
    static let controllerField = "Controller"
    static let accountField = "Account"

    case staked
    case stash
    case controller
    case account(_ accountId: Data)
}

extension RewardDestinationArg: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.stakedField:
            self = .staked
        case Self.stashField:
            self = .stash
        case Self.controllerField:
            self = .controller
        case Self.accountField:
            let data = try container.decode(Data.self)
            self = .account(data)
        default:
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unexpected type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .staked:
            try container.encode(Self.stakedField)
            try container.encodeNil()
        case .stash:
            try container.encode(Self.stashField)
            try container.encodeNil()
        case .controller:
            try container.encode(Self.controllerField)
            try container.encodeNil()
        case .account(let data):
            try container.encode(Self.accountField)
            try container.encode(data)
        }
    }
}
