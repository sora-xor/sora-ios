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

struct ExtrinsicPayload: ScaleEncodable {
    let call: Call
    let era: Era
    let nonce: UInt32
    let tip: BigUInt
    let specVersion: UInt32
    let transactionVersion: UInt32
    let genesisHash: Data
    let blockHash: Data

    func encode(scaleEncoder: ScaleEncoding) throws {
        try call.moduleIndex.encode(scaleEncoder: scaleEncoder)
        try call.callIndex.encode(scaleEncoder: scaleEncoder)

        if let arguments = call.arguments {
            scaleEncoder.appendRaw(data: arguments)
        }

        try era.encode(scaleEncoder: scaleEncoder)
        try BigUInt(nonce).encode(scaleEncoder: scaleEncoder)
        try tip.encode(scaleEncoder: scaleEncoder)
        try specVersion.encode(scaleEncoder: scaleEncoder)
        try transactionVersion.encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: genesisHash)
        scaleEncoder.appendRaw(data: blockHash)
    }
}
