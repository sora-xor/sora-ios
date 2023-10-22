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
import sorawallet

protocol HistoryTransactionMapperProtocol {
    func map(items: [TxHistoryItem]) -> [Transaction?]
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
    func map(items: [TxHistoryItem]) -> [Transaction?] {
        return items.compactMap { item in
            let transactionBase = TransactionBase(txHash: item.id,
                                                  blockHash: item.blockHash,
                                                  fee: Amount(string: item.networkFee) ?? Amount(value: 0),
                                                  status: item.success ? TransactionBase.Status.success : TransactionBase.Status.failed,
                                                  timestamp: item.timestamp)
            let callPath = KmmCallCodingPath(moduleName: item.module, callName: item.method)
            
            if callPath.isTransfer {
                guard let transferData = item.data?.toTransferData() else {
                    return nil
                }
                
                return TransferTransaction(base: transactionBase,
                                           amount: Amount(string: transferData.amount) ?? Amount(value: 0),
                                           peer: transferData.to == myAddress ? transferData.from : transferData.to,
                                           transferType: transferData.to == myAddress ? .incoming : .outcoming,
                                           tokenId: transferData.assetId)
            }
            
            if callPath == KmmCallCodingPath.bondReferralBalance {
                guard let referralBondData = item.data?.toReferralData() else {
                    return nil
                }
                
                return ReferralBondTransaction(base: transactionBase,
                                               amount: Amount(string: referralBondData.amount) ?? Amount(value: 0),
                                               tokenId: assets.first { $0.isFeeAsset }?.identifier ?? "",
                                               type: .bond)
            }
            
            if callPath == KmmCallCodingPath.unbondReferralBalance {
                guard let referralBondData = item.data?.toReferralData() else {
                    return nil
                }
                
                return ReferralBondTransaction(base: transactionBase,
                                               amount: Amount(string: referralBondData.amount) ?? Amount(value: 0),
                                               tokenId: assets.first { $0.isFeeAsset }?.identifier ?? "",
                                               type: .unbond)
            }
            
            if callPath == KmmCallCodingPath.setReferral {
                guard let setReferrerData = item.data?.toSetReferrerData(with: myAddress) else {
                    return nil
                }
                
                return SetReferrerTransaction(base: transactionBase,
                                              who: setReferrerData.address,
                                              isMyReferrer: setReferrerData.my,
                                              tokenId: assets.first { $0.isFeeAsset }?.identifier ?? "")
            }
            
            if callPath.isSwap {
                guard let swapData = item.data?.toSwapData() else {
                    return nil
                }

                let market = LiquiditySourceType.allCases.first(where: { $0.rawValue == swapData.selectedMarket }) ?? LiquiditySourceType.smart
                return Swap(base: transactionBase,
                            fromTokenId: swapData.baseTokenId,
                            toTokenId: swapData.targetTokenId,
                            fromAmount: Amount(string: swapData.baseTokenAmount) ?? Amount(value: 0),
                            toAmount: Amount(string: swapData.targetTokenAmount) ?? Amount(value: 0),
                            market: market,
                            lpFee: Amount(string: swapData.liquidityProviderFee) ?? Amount(value: 0))
            }
            
            if callPath.isDepositLiquidity || callPath.isWithdrawLiquidity {
                guard let liquidityData = item.data?.toLiquidityData() else {
                    return nil
                }

                return Liquidity(base: transactionBase,
                                 firstTokenId: liquidityData.baseTokenId,
                                 secondTokenId: liquidityData.targetTokenId,
                                 firstAmount: Amount(string: liquidityData.baseTokenAmount) ?? Amount(value: 0),
                                 secondAmount: Amount(string: liquidityData.targetTokenAmount) ?? Amount(value: 0),
                                 type: item.method == "depositLiquidity" ? .add : .withdraw)
            }
            
            if callPath == KmmCallCodingPath.batchUtility || callPath == KmmCallCodingPath.batchAllUtility {
                let depositLiquidityData = item.nestedData?.first { $0.method == "depositLiquidity" }
                
                if depositLiquidityData != nil {
                    guard let liquidityBatchData = depositLiquidityData?.data.toLiquidityBatchData() else {
                        return nil
                    }
                    
                    return Liquidity(base: transactionBase,
                                     firstTokenId: liquidityBatchData.baseTokenId,
                                     secondTokenId: liquidityBatchData.targetTokenId,
                                     firstAmount: Amount(string: liquidityBatchData.baseTokenAmount) ?? Amount(value: 0),
                                     secondAmount: Amount(string: liquidityBatchData.targetTokenAmount) ?? Amount(value: 0),
                                     type: .add)
                }
                
                
                let withdrawLiquidityData = item.nestedData?.first { $0.method == "withdrawLiquidity" }
                if withdrawLiquidityData != nil {
                    guard let liquidityBatchData = withdrawLiquidityData?.data.toLiquidityBatchData()  else {
                        return nil
                    }
                    
                    return Liquidity(base: transactionBase,
                                     firstTokenId: liquidityBatchData.baseTokenId,
                                     secondTokenId: liquidityBatchData.targetTokenId,
                                     firstAmount: Amount(string: liquidityBatchData.baseTokenAmount) ?? Amount(value: 0),
                                     secondAmount: Amount(string: liquidityBatchData.targetTokenAmount) ?? Amount(value: 0),
                                     type: .withdraw)
                }
            }

            return nil
        }
    }
}
