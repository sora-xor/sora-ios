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

    /// The amounts a swap signs, in the chain units of each asset.
    ///
    /// `amount` is in the source asset, the estimated amount in the
    /// destination asset. Each is scaled by the decimals of its own asset:
    /// the fixed side exactly, the slippage limit to whole units as master
    /// rounds it (minimum received down, maximum sold up). The decimals come
    /// from the caller, which takes them from the account's assets, never
    /// from an assumed 18.
    func amountCall(
        sourcePrecision: Int16,
        destinationPrecision: Int16
    ) -> [SwapVariant: SwapAmount]? {
        guard sourcePrecision >= 0,
              destinationPrecision >= 0,
              WalletAssetPrecision.isPossible(UInt32(sourcePrecision)),
              WalletAssetPrecision.isPossible(UInt32(destinationPrecision)) else {
            return nil
        }
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
                // The review states the limit in whole units of the asset;
                // either form of it names the same signed units.
                let signedMinimum = slippage.minimumAmount(for: estimatedAmount.decimalValue,
                                                          precision: destinationPrecision)
                guard self.amount.decimalValue > 0,
                      minMaxAmount.decimalValue > 0,
                      minMaxAmount.decimalValue == expectedMinimum || minMaxAmount.decimalValue == signedMinimum,
                      let desiredValue = Self.exactSubstrateAmount(
                        self.amount.decimalValue,
                        precision: sourcePrecision
                      ),
                      let slipValue = expectedMinimum.toSubstrateAmountRoundingDown(precision: destinationPrecision),
                      desiredValue > 0,
                      slipValue > 0 else {
                    return nil
                }
                desired = desiredValue
                slip = slipValue
            case .desiredOutput:
                let expectedMaximum = slippage.maximumAmount(for: self.amount.decimalValue)
                let signedMaximum = slippage.maximumAmount(for: self.amount.decimalValue,
                                                          precision: sourcePrecision)
                guard estimatedAmount.decimalValue > 0,
                      minMaxAmount.decimalValue > 0,
                      minMaxAmount.decimalValue == expectedMaximum || minMaxAmount.decimalValue == signedMaximum,
                      let desiredValue = Self.exactSubstrateAmount(
                        estimatedAmount.decimalValue,
                        precision: destinationPrecision
                      ),
                      let slipValue = expectedMaximum.toSubstrateAmountRoundingUp(precision: sourcePrecision),
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

    /// The fixed side of a swap in chain units, or nil when the asset cannot
    /// hold the amount exactly. A reviewed 10.015 of an asset with two
    /// decimals must not be signed as 10.01.
    private static func exactSubstrateAmount(
        _ value: Decimal,
        precision: Int16
    ) -> BigUInt? {
        guard value > 0,
              let units = value.toSubstrateAmount(precision: precision),
              Decimal.fromSubstrateAmount(units, precision: precision) == value else {
            return nil
        }
        return units
    }
}
