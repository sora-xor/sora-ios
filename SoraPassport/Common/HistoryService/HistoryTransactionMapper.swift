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
import sorawallet

enum HistoryTransactionMapperError: Swift.Error {
    case unexpectedError
}

protocol HistoryTransactionMapperProtocol {
    func map(items: [TxHistoryItem]) throws -> [Transaction?]
}

final class HistoryTransactionMapper {
    
    private let myAddress: String
    private let assets: [AssetInfo]
    
    init(myAddress: String, assets: [AssetInfo]) {
        self.myAddress = myAddress
        self.assets = assets
    }
}

extension HistoryTransactionMapper: HistoryTransactionMapperProtocol {
    func map(items: [TxHistoryItem]) throws -> [Transaction?] {
        return try items.compactMap { item in
            let networkFee = try Self.validatedFee(item.networkFee)
            let transactionBase = TransactionBase(txHash: item.id,
                                                  blockHash: item.blockHash,
                                                  fee: networkFee,
                                                  status: item.success ? TransactionBase.Status.success : TransactionBase.Status.failed,
                                                  timestamp: item.timestamp)
            let callPath = KmmCallCodingPath(moduleName: item.module, callName: item.method)
            
            if callPath.isTransfer {
                guard let transferData = item.data?.toTransferData() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }
                
                return TransferTransaction(base: transactionBase,
                                           amount: try Self.validatedAmount(transferData.amount),
                                           peer: transferData.to == myAddress ? transferData.from : transferData.to,
                                           transferType: transferData.to == myAddress ? .incoming : .outcoming,
                                           tokenId: transferData.assetId)
            }
            
            if callPath == KmmCallCodingPath.bondReferralBalance {
                guard let referralBondData = item.data?.toReferralData() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }
                
                return ReferralBondTransaction(base: transactionBase,
                                               amount: try Self.validatedAmount(referralBondData.amount),
                                               tokenId: assets.first { $0.isFeeAsset }?.identifier ?? "",
                                               type: .bond)
            }
            
            if callPath == KmmCallCodingPath.unbondReferralBalance {
                guard let referralBondData = item.data?.toReferralData() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }
                
                return ReferralBondTransaction(base: transactionBase,
                                               amount: try Self.validatedAmount(referralBondData.amount),
                                               tokenId: assets.first { $0.isFeeAsset }?.identifier ?? "",
                                               type: .unbond)
            }
            
            if callPath == KmmCallCodingPath.setReferral {
                guard let setReferrerData = item.data?.toSetReferrerData(with: myAddress) else {
                    throw HistoryTransactionMapperError.unexpectedError
                }
                
                return SetReferrerTransaction(base: transactionBase,
                                              who: setReferrerData.address,
                                              isMyReferrer: setReferrerData.my,
                                              tokenId: assets.first { $0.isFeeAsset }?.identifier ?? "")
            }
            
            if callPath.isSwap {
                guard let swapData = item.data?.toSwapData() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }

                let market = LiquiditySourceType.allCases.first(where: { $0.rawValue == swapData.selectedMarket }) ?? LiquiditySourceType.smart
                return Swap(base: transactionBase,
                            fromTokenId: swapData.baseTokenId,
                            toTokenId: swapData.targetTokenId,
                            fromAmount: try Self.validatedAmount(swapData.baseTokenAmount),
                            toAmount: try Self.validatedAmount(swapData.targetTokenAmount),
                            market: market)
            }
            
            if callPath.isDepositLiquidity || callPath.isWithdrawLiquidity {
                guard let liquidityData = item.data?.toLiquidityData() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }

                return Liquidity(base: transactionBase,
                                 firstTokenId: liquidityData.baseTokenId,
                                 secondTokenId: liquidityData.targetTokenId,
                                 firstAmount: try Self.validatedAmount(liquidityData.baseTokenAmount),
                                 secondAmount: try Self.validatedAmount(liquidityData.targetTokenAmount),
                                 type: item.method == "depositLiquidity" ? .add : .withdraw)
            }
            
            if callPath.isClaimReward {
                guard let claimData = item.data?.toClaimRewardData() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }

                let amount = try Self.validatedAmount(claimData.amount)
                return ClaimReward(base: transactionBase,
                                   amount: amount,
                                   peer: SelectedWalletSettings.shared.currentAccount?.address ?? "",
                                   rewardTokenId: claimData.rewardAssetId)
            }
            
            if callPath.isDepositFarmLiquidity || callPath.isWithdrawFarmLiquidity {
                guard let data = item.data?.toFarmLiquidity() else {
                    throw HistoryTransactionMapperError.unexpectedError
                }

                let amount = try Self.validatedAmount(data.amount)
                return FarmLiquidity(base: transactionBase,
                                     firstTokenId: data.baseTokenAmount,
                                     secondTokenId: data.poolTokenAmount,
                                     rewardTokenId: data.rewardAssetId,
                                     amount: amount,
                                     sender: SelectedWalletSettings.shared.currentAccount?.address ?? "",
                                     type: item.method == "deposit" ? .add : .withdraw)
            }
            
            if callPath == KmmCallCodingPath.batchUtility || callPath == KmmCallCodingPath.batchAllUtility {
                let depositLiquidityData = item.nestedData?.first { $0.method == "depositLiquidity" }
                
                if depositLiquidityData != nil {
                    guard let liquidityBatchData = depositLiquidityData?.data.toLiquidityBatchData() else {
                        throw HistoryTransactionMapperError.unexpectedError
                    }
                    
                    return Liquidity(base: transactionBase,
                                     firstTokenId: liquidityBatchData.baseTokenId,
                                     secondTokenId: liquidityBatchData.targetTokenId,
                                     firstAmount: try Self.validatedAmount(liquidityBatchData.baseTokenAmount),
                                     secondAmount: try Self.validatedAmount(liquidityBatchData.targetTokenAmount),
                                     type: .add)
                }
                
                
                let withdrawLiquidityData = item.nestedData?.first { $0.method == "withdrawLiquidity" }
                if withdrawLiquidityData != nil {
                    guard let liquidityBatchData = withdrawLiquidityData?.data.toLiquidityBatchData()  else {
                        throw HistoryTransactionMapperError.unexpectedError
                    }
                    
                    return Liquidity(base: transactionBase,
                                     firstTokenId: liquidityBatchData.baseTokenId,
                                     secondTokenId: liquidityBatchData.targetTokenId,
                                     firstAmount: try Self.validatedAmount(liquidityBatchData.baseTokenAmount),
                                     secondAmount: try Self.validatedAmount(liquidityBatchData.targetTokenAmount),
                                     type: .withdraw)
                }
            }

            return nil
        }
    }

    static func validatedAmount(_ rawValue: String) throws -> Amount {
        guard
            !rawValue.hasPrefix("-"),
            rawValue.utf8.count <= PIQuantity.maximumWireBytes,
            rawValue.range(
                of: #"^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$"#,
                options: .regularExpression
            ) != nil,
            let parsed = Decimal(
                string: rawValue,
                locale: Locale(identifier: "en_US_POSIX")
            )
        else {
            throw HistoryTransactionMapperError.unexpectedError
        }
        var decimalValue = parsed
        let roundTrip = NSDecimalString(
            &decimalValue,
            Locale(identifier: "en_US_POSIX")
        )
        guard canonicalDecimal(roundTrip) == canonicalDecimal(rawValue) else {
            throw HistoryTransactionMapperError.unexpectedError
        }
        return Amount(value: parsed)
    }

    static func validatedFee(_ rawValue: String) throws -> Amount {
        guard
            rawValue.utf8.count <= PIQuantity.maximumWireBytes,
            rawValue.range(
                of: #"^(?:0|[1-9][0-9]*)$"#,
                options: .regularExpression
            ) != nil
        else {
            throw HistoryTransactionMapperError.unexpectedError
        }
        return try validatedAmount(rawValue)
    }

    private static func canonicalDecimal(_ rawValue: String) -> String {
        guard let separator = rawValue.firstIndex(of: ".") else {
            return rawValue
        }
        let integer = rawValue[..<separator]
        var fraction = String(rawValue[rawValue.index(after: separator)...])
        while fraction.last == "0" {
            fraction.removeLast()
        }
        return fraction.isEmpty ? String(integer) : "\(integer).\(fraction)"
    }
}
