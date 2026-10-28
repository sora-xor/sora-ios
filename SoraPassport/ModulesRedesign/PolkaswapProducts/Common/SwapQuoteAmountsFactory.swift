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
import BigInt

protocol SwapQuoteConverterProtocol {
    func createAmounts(fromAsset: AssetInfo, toAsset: AssetInfo, params: PolkaswapMainInteractorQuoteParams, quote: SwapValues) -> SwapQuoteAmounts?
}

struct SwapQuoteAmounts: Equatable {
    let fromAmount: Decimal
    let toAmount: Decimal
}

class SwapQuoteAmountsFactory: SwapQuoteConverterProtocol {
    func createAmounts(fromAsset: AssetInfo, toAsset: AssetInfo, params: PolkaswapMainInteractorQuoteParams, quote: SwapValues) -> SwapQuoteAmounts? {
        guard
            let fromAmountBig = BigUInt(params.amount),
            let toAmountBig = BigUInt(quote.amount),
            let fromAmount = Decimal.fromSubstrateAmount(fromAmountBig, precision: Int16(fromAsset.precision)),
            let toAmount = Decimal.fromSubstrateAmount(toAmountBig, precision: Int16(toAsset.precision)) else {
                return nil
        }

        return SwapQuoteAmounts(fromAmount: fromAmount, toAmount: toAmount)
    }
}
