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
        amountCall(sourcePrecision: 18, destinationPrecision: 18)
    }

    func amountCall(
        sourcePrecision: Int16,
        destinationPrecision: Int16
    ) -> [SwapVariant: SwapAmount]? {
        if type == .swap,
           let context = self.context,
           let raw = context[TransactionContextKeys.desire],
           let desire = SwapVariant(rawValue: raw),
           let estimated =  context[TransactionContextKeys.estimatedAmount],
           let estimatedAmount = AmountDecimal(string: estimated),
           let minMax = context[TransactionContextKeys.minMaxValue],
           let minMaxAmount = AmountDecimal(string: minMax) {
            let desired: BigUInt
            let slip: BigUInt
            switch desire {
            case .desiredInput:
                guard
                    let desiredAmount = self.amount.decimalValue.toSubstrateAmount(
                        precision: sourcePrecision
                    ),
                    let minimumOutput = minMaxAmount.decimalValue.toSubstrateAmountRoundingDown(
                        precision: destinationPrecision
                    )
                else {
                    return nil
                }
                desired = desiredAmount
                slip = minimumOutput
            case .desiredOutput:
                guard
                    let desiredAmount = estimatedAmount.decimalValue.toSubstrateAmount(
                        precision: destinationPrecision
                    ),
                    let maximumInput = minMaxAmount.decimalValue.toSubstrateAmountRoundingUp(
                        precision: sourcePrecision
                    )
                else {
                    return nil
                }
                desired = desiredAmount
                slip = maximumInput
            }

            return [desire: SwapAmount(type: desire, desired: desired, slip: slip)]
        }
        return nil
    }
}
