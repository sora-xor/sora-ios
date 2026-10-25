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

import BigInt

extension TransferInfo {
    var type: TransactionType {
        if let context = self.context,
           let type = context[TransactionContextKeys.transactionType] {
            return TransactionType(rawValue: type) ?? TransactionType.outgoing
        }
        return TransactionType.outgoing
    }

    var amountCall: [SwapVariant: SwapAmount]? {
        if type == .swap,
           let context = self.context,
           let raw = context[TransactionContextKeys.desire],
           let desire = SwapVariant(rawValue: raw),
           let estimated =  context[TransactionContextKeys.estimatedAmount],
           let estimatedAmount = AmountDecimal(string: estimated),
           let minMax = context[TransactionContextKeys.minMaxValue],
           let minMaxAmount = AmountDecimal(string: minMax),
           let rawSlippage = context[TransactionContextKeys.slippage],
           let slippage = PolkaswapSlippage(contextValue: rawSlippage) {
            let desired: BigUInt
            let slip: BigUInt
            switch desire {
            case .desiredInput:
                let expectedMinimum = slippage.minimumAmount(for: estimatedAmount.decimalValue)
                guard self.amount.decimalValue > 0,
                      minMaxAmount.decimalValue > 0,
                      minMaxAmount.decimalValue == expectedMinimum,
                      let desiredValue = self.amount.decimalValue.toSubstrateAmount(precision: 18),
                      let slipValue = expectedMinimum.toSubstrateAmountRoundingDown(precision: 18),
                      desiredValue > 0,
                      slipValue > 0 else {
                    return nil
                }
                desired = desiredValue
                slip = slipValue
            case .desiredOutput:
                let expectedMaximum = slippage.maximumAmount(for: self.amount.decimalValue)
                guard estimatedAmount.decimalValue > 0,
                      minMaxAmount.decimalValue > 0,
                      minMaxAmount.decimalValue == expectedMaximum,
                      let desiredValue = estimatedAmount.decimalValue.toSubstrateAmount(precision: 18),
                      let slipValue = expectedMaximum.toSubstrateAmountRoundingUp(precision: 18),
                      desiredValue > 0,
                      slipValue > 0 else {
                    return nil
                }
                desired = desiredValue
                slip = slipValue
            }

            return [desire: SwapAmount(type: desire, desired: desired, slip: slip)]
        }
        return nil
    }
}
