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
import SSFUtils
import BigInt

struct Header: ScaleDecodable {

    let parentHash: String
    let stateRoot: String
    @StringCodable var number: UInt32
    let extrinsicRoot: String
    let digest: [String : String]

    enum CodingKeys: String, CodingKey {
        case parentHash
        case stateRoot
        case number
        case extrinsicRoot
    }

    init(scaleDecoder: ScaleDecoding) throws {
        parentHash = try String(scaleDecoder: scaleDecoder)
        stateRoot = try String(scaleDecoder: scaleDecoder)
        number = try UInt32(scaleDecoder: scaleDecoder)
        extrinsicRoot = try String(scaleDecoder: scaleDecoder)
        digest = [:]
    }

//    public init(from decoder: Decoder) throws {
//        var container = try decoder.container(keyedBy: CodingKeys.self)
//
//        parentHash = try container.decode(String.self, forKey: .parentHash)
//        stateRoot = try container.decode(String.self, forKey: .stateRoot)
//        number = try container.decode(BigUInt.self, forKey: .number)
//        extrinsicRoot = try container.decode(String.self, forKey: .extrinsicRoot)
//        digest = [:]
//    }
}
