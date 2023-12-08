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
