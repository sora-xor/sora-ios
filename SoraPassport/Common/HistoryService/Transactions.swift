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
import UIKit
import sorawallet
import SoraUIKit

protocol Transaction {
    var base: TransactionBase { get set }
}

struct TransactionBase {
    enum Status: Int16, Codable {
        case pending
        case success
        case failed
        
        var title: String {
            switch self {
            case .failed: return R.string.localizable.commonFailed(preferredLanguages: .currentLocale)
            case .pending: return R.string.localizable.walletTxDetailsPending(preferredLanguages: .currentLocale)
            case .success: return R.string.localizable.statusSuccessful(preferredLanguages: .currentLocale)
            }
        }
        
        var color: SoramitsuColor {
            switch self {
            case .failed: return .statusError
            case .pending: return .fgSecondary
            case .success: return .statusSuccess
            }
        }
        
        var image: UIImage? {
            switch self {
            case .failed: return R.image.wallet.failStatus()
            case .pending: return R.image.wallet.pendingStatus()
            case .success: return nil
            }
        }
    }
    
    let txHash: String
    let blockHash: String
    let fee: Amount
    var status: Status
    let timestamp: String
}

struct TransferTransaction: Transaction {

    enum TransferType {
        case incoming
        case outcoming
        
        var title: String {
            switch self {
            case .incoming: return R.string.localizable.commonReceived(preferredLanguages: .currentLocale)
            case .outcoming: return R.string.localizable.commonSent(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .incoming: return R.image.wallet.receive()
            case .outcoming: return R.image.wallet.send()
            }
        }
        
        var detailsTitle: String {
            switch self {
            case .incoming: return R.string.localizable.commonReceived(preferredLanguages: .currentLocale)
            case .outcoming: return R.string.localizable.commonSent(preferredLanguages: .currentLocale)
            }
        }
    }
    
    var base: TransactionBase
    let amount: Amount
    let peer: String
    let transferType: TransferType
    let tokenId: String
}

struct ClaimReward: Transaction {
    var base: TransactionBase
    let amount: Amount
    let peer: String
    let rewardTokenId: String
}

struct ReferralBondTransaction: Transaction {

    enum ReferralTransactionType {
        case bond
        case unbond
        
        var title: String {
            switch self {
            case .bond: return R.string.localizable.activityBondTitle(preferredLanguages: .currentLocale)
            case .unbond: return R.string.localizable.activityUnbondTitle(preferredLanguages: .currentLocale)
            }
        }
        
        var detailsTitle: String {
            switch self {
            case .bond: return R.string.localizable.walletBonded(preferredLanguages: .currentLocale)
            case .unbond: return R.string.localizable.walletUnbonded(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .bond: return R.image.wallet.send()
            case .unbond: return  R.image.wallet.receive()
            }
        }
    }
    
    var base: TransactionBase
    let amount: Amount
    let tokenId: String
    let type: ReferralTransactionType
}

struct SetReferrerTransaction: Transaction {
    var base: TransactionBase
    let who: String
    let isMyReferrer: Bool
    let tokenId: String
}

struct Swap: Transaction {
    var base: TransactionBase
    let fromTokenId: String
    let toTokenId: String
    let fromAmount: Amount
    let toAmount: Amount
    let market: LiquiditySourceType
}

struct Liquidity: Transaction {
    enum TransactionLiquidityType {
        case add
        case withdraw
        
        var subtitle: String {
            switch self {
            case .add: return R.string.localizable.activityAddLiquidityTitle(preferredLanguages: .currentLocale)
            case .withdraw: return R.string.localizable.commonWithdraw(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .add: return R.image.wallet.send()
            case .withdraw: return R.image.wallet.receive()
            }
        }
    }
    var base: TransactionBase
    let firstTokenId: String
    let secondTokenId: String
    let firstAmount: Amount
    let secondAmount: Amount
    let type: TransactionLiquidityType
}

struct FarmLiquidity: Transaction {
    enum TransactionLiquidityType {
        case add
        case withdraw
        
        var subtitle: String {
            switch self {
            case .add: return R.string.localizable.demeterStakedLiquidity(preferredLanguages: .currentLocale)
            case .withdraw: return R.string.localizable.demeterUnstakedLiquidity(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .add: return R.image.wallet.send()
            case .withdraw: return R.image.wallet.receive()
            }
        }
    }
    var base: TransactionBase
    let firstTokenId: String
    let secondTokenId: String
    let rewardTokenId: String
    let amount: Amount
    let sender: String
    let type: TransactionLiquidityType
}

/// A transaction this device signed and handed to the network, known from
/// the app's own journal of sent transactions and (so far) not listed by the
/// indexer. The journal keeps the transaction's hash and its fate, not what
/// it did: the row says that a transaction was sent and what became of it.
/// When the indexer lists the transaction, its row replaces this one.
struct SubmittedTransaction: Transaction {
    enum Outcome: Equatable {
        /// Handed to the network; no final result yet.
        case pending
        /// In a finalized block, executed successfully.
        case succeeded
        /// In a finalized block, and the chain rejected its effect.
        case failed
        /// Its validity period ended and it is not on the chain. Nothing
        /// moved and it can no longer be included.
        case notIncluded

        var status: TransactionBase.Status {
            switch self {
            case .pending: return .pending
            case .succeeded: return .success
            case .failed, .notIncluded: return .failed
            }
        }

        /// One line saying what became of the transaction.
        var explanation: String {
            switch self {
            case .pending:
                return WalletUX.text("Waiting for the network to confirm it")
            case .succeeded:
                return WalletUX.text("Confirmed by the network")
            case .failed:
                return WalletUX.text("It failed on the network")
            case .notIncluded:
                return WalletUX.text("The network did not include it. Nothing was sent.")
            }
        }
    }

    var base: TransactionBase
    let outcome: Outcome

    static var title: String { WalletUX.text("Sent transaction") }
}

struct TransferData {
    let to: String
    let from: String
    let amount: String
    let assetId: String
}

struct ReferralData {
    let amount: String
}

struct SetReferrerData {
    let address: String
    let my: Bool
}

struct SwapData {
    let selectedMarket: String
    let liquidityProviderFee: String
    let baseTokenId: String
    let targetTokenId: String
    let baseTokenAmount: String
    let targetTokenAmount: String
}

struct LiquidityData {
    let baseTokenId: String
    let targetTokenId: String
    let baseTokenAmount: String
    let targetTokenAmount: String
}

struct ClaimRewardsData {
    let amount: String
    let rewardAssetId: String
}

struct FarmLiquidityData {
    let baseTokenAmount: String
    let poolTokenAmount: String
    let rewardAssetId: String
    let amount: String
}


extension Array where Element == TxHistoryItemParam {
    func toTransferData() -> TransferData {
        return TransferData(to: self.first { $0.paramName == "to" }?.paramValue ?? "",
                            from: self.first { $0.paramName == "from" }?.paramValue ?? "",
                            amount: self.first { $0.paramName == "amount" }?.paramValue ?? "",
                            assetId: self.first { $0.paramName == "assetId" }?.paramValue ?? "")
    }
    
    func toReferralData() -> ReferralData {
        return ReferralData(amount: self.first { $0.paramName == "amount" }?.paramValue ?? "")
    }
    
    func toSetReferrerData(with myAddress: String) -> SetReferrerData {
        let to = self.first { $0.paramName == "to" }?.paramValue ?? ""
        let from = self.first { $0.paramName == "from" }?.paramValue ?? ""
        let isMyReferrer = from == myAddress
        
        return SetReferrerData(address: isMyReferrer ? to : from, my: isMyReferrer)
    }
    
    func toSwapData() -> SwapData {
        return SwapData(selectedMarket: self.first { $0.paramName == "selectedMarket" }?.paramValue ?? "" ,
                        liquidityProviderFee: self.first { $0.paramName == "liquidityProviderFee" }?.paramValue ?? "" ,
                        baseTokenId: self.first { $0.paramName == "baseAssetId" }?.paramValue ?? "" ,
                        targetTokenId: self.first { $0.paramName == "targetAssetId" }?.paramValue ?? "" ,
                        baseTokenAmount: self.first { $0.paramName == "baseAssetAmount" }?.paramValue ?? "" ,
                        targetTokenAmount: self.first { $0.paramName == "targetAssetAmount" }?.paramValue ?? "")
    }
    
    func toLiquidityData() -> LiquidityData {
        return LiquidityData(baseTokenId: self.first { $0.paramName == "targetAssetId" }?.paramValue ?? "" ,
                             targetTokenId: self.first { $0.paramName == "baseAssetId" }?.paramValue ?? "" ,
                             baseTokenAmount: self.first { $0.paramName == "baseAssetAmount" }?.paramValue ?? "" ,
                             targetTokenAmount: self.first { $0.paramName == "targetAssetAmount" }?.paramValue ?? "" )
    }
    
    func toLiquidityBatchData() -> LiquidityData {
        return LiquidityData(baseTokenId: self.first { $0.paramName == "input_asset_a" }?.paramValue ?? "" ,
                             targetTokenId: self.first { $0.paramName == "input_asset_b" }?.paramValue ?? "" ,
                             baseTokenAmount: self.first { $0.paramName == "input_a_desired" }?.paramValue ?? "" ,
                             targetTokenAmount: self.first { $0.paramName == "input_b_desired" }?.paramValue ?? "" )
    }
    
    func toClaimRewardData() -> ClaimRewardsData {
        return ClaimRewardsData(amount: self.first { $0.paramName == "amount" }?.paramValue ?? "" ,
                                rewardAssetId: self.first { $0.paramName == "assetId" }?.paramValue ?? "")
    }
    
    func toFarmLiquidity() -> FarmLiquidityData {
        return FarmLiquidityData(baseTokenAmount: self.first { $0.paramName == "baseAssetId" }?.paramValue ?? "",
                                 poolTokenAmount: self.first { $0.paramName == "assetId" }?.paramValue ?? "",
                                 rewardAssetId: self.first { $0.paramName == "rewardAssetId" }?.paramValue ?? "",
                                 amount: self.first { $0.paramName == "amount" }?.paramValue ?? "")
    }
}
