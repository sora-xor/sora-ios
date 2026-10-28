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
import Foundation

extension Era {

    public static let defaultEraLength: UInt64 = 64

    public init(blockNumber: UInt64, eraLength: UInt64 = defaultEraLength) {
        var calPeriod = UInt64(pow(2.0, ceil(log2(Float(eraLength)))))
        calPeriod = min(1 << 16, max(calPeriod, 4))
        let phase = blockNumber % calPeriod
        let quantizeFactor = max(1, calPeriod >> 12)
        let quatizePhase = UInt64(phase / quantizeFactor * quantizeFactor)
//        var calPeriod = 2.0.pow(ceil(log2(periodInBlocks.toDouble()))).toInt()
//        calPeriod = min(1 shl 16, max(calPeriod, 4))
//        val phase = currentBlockNumber % calPeriod
//        val quantizeFactor = max(1, calPeriod shr 12)
//        val quantizePhase = phase / quantizeFactor * quantizeFactor
        self = Era.mortal(period: calPeriod, phase: quatizePhase)
    }
}
