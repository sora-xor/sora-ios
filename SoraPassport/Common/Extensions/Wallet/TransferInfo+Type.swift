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
