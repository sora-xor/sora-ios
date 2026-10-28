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

struct EthereumSignature: Codable {
    enum CodingKeys: String, CodingKey {
        case vPart = "v"
        case rPart = "r"
        case sPart = "s"
    }

    let vPart: UInt8
    let rPart: Data
    let sPart: Data

    init(vPart: UInt8, rPart: Data, sPart: Data) {
        self.vPart = vPart
        self.rPart = rPart
        self.sPart = sPart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let vPartString = try container.decode(String.self, forKey: .vPart)
        let vPartData = try NSData(hexString: vPartString) as Data
        vPart = 0//vPartData.bytes[0]

        let rPartString = try container.decode(String.self, forKey: .rPart)
        rPart = try NSData(hexString: rPartString) as Data

        let sPartString = try container.decode(String.self, forKey: .sPart)
        sPart = try NSData(hexString: sPartString) as Data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(Data([vPart]).soraHex, forKey: .vPart)
        try container.encode(rPart.soraHex, forKey: .rPart)
        try container.encode(sPart.soraHex, forKey: .sPart)
    }
}
