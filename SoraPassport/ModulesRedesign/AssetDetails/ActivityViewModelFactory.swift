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

import SoraUIKit
import UIKit
import sorawallet
import SoraFoundation

protocol ActivityViewModelFactoryProtocol {
    var currentDate: Date? { get set } 
    func createActivityViewModels(with transactions: [Transaction],
                                  tapHandler: @escaping (Transaction) -> Void) -> [ActivitySection]
    func createActivityShimmerModels() -> [ActivitySection]
    func createActivityViewModel(with transaction: Transaction) -> ActivityContentViewModel?
}

final class ActivityViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    var currentDate: Date?

    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
    }
}

extension ActivityViewModelFactory: ActivityViewModelFactoryProtocol {
    func createActivityViewModels(with transactions: [Transaction],
                                  tapHandler: @escaping (Transaction) -> Void) -> [ActivitySection] {
        var sections: [ActivitySection] = []
        var items: [ActivitySectionItem] = []

        transactions.forEach { transaction in
            let transactionDate = Date(timeIntervalSince1970: Double(transaction.base.timestamp) ?? 0)

            let dateOrder = Calendar.current.compare(transactionDate, to: currentDate ?? Date(), toGranularity: .day)

            if let currentDate = currentDate, dateOrder != .orderedSame, !items.isEmpty {
                sections.append(ActivitySection(date: DateFormatter.activityDate.string(from: currentDate),
                                                items: items))
                items = []
            }

            currentDate = transactionDate

            if let transactionModel = createActivityViewModel(with: transaction) {
                let activityItem = ActivityItem(model: transactionModel)
                activityItem.handler = {
                    tapHandler(transaction)
                }
                items.append(.activity(activityItem))
            }
        }

        if let currentDate = currentDate, !items.isEmpty {
            sections.append(ActivitySection(date: DateFormatter.activityDate.string(from: currentDate),
                                            items: items))
        }

        return sections
    }

    func createActivityViewModel(with transaction: Transaction) -> ActivityContentViewModel? {
        if let transferTransaction = transaction as? TransferTransaction {
            return transferTransactionViewModel(from: transferTransaction)
        }

        if let swapTransaction = transaction as? Swap {
            return swapTransactionViewModel(from: swapTransaction)
        }

        if let liquidityTransaction = transaction as? Liquidity {
            return liquidityTransactionViewModel(from: liquidityTransaction)
        }

        if let bondTransaction = transaction as? ReferralBondTransaction {
            return bondTransactionViewModel(from: bondTransaction)
        }

        if let setReferrerTransaction = transaction as? SetReferrerTransaction {
            return setReferrerTransactionViewModel(from: setReferrerTransaction)
        }

        if let claimRewardTransaction = transaction as? ClaimReward {
            return claimRewardTransactionViewModel(from: claimRewardTransaction)
        }
        
        if let farmLiquidity = transaction as? FarmLiquidity {
            return farmLiquidityTransactionViewModel(from: farmLiquidity)
        }

        if let submitted = transaction as? SubmittedTransaction {
            return submittedTransactionViewModel(from: submitted)
        }
      
        return nil
    }

    func createActivityShimmerModels() -> [ActivitySection] {
        let shimmerItems: [ActivitySectionItem] = (1...20).map { index in
            let model = ActivityContentViewModel(txHash: "\(index)")
            let item = ActivityItem(model: model)
            return .activity(item)
        }

        let spaceSection = ActivitySection(items: [.space(SoramitsuTableViewSpacerItem(space: 24,
                                                                                 radius: .extraLarge,
                                                                                 mask: .top))])

        let shimmerSection = ActivitySection(date: DateFormatter.activityDate.string(from: Date()),
                                             items: shimmerItems)

        return [spaceSection, shimmerSection]
    }
}

private extension ActivityViewModelFactory {
    /// A sent transaction known only from the app's own journal: what it
    /// is and what became of it. The journal does not keep amounts, so the
    /// row shows none; the network's fee token stands for the network.
    func submittedTransactionViewModel(from transaction: SubmittedTransaction) -> ActivityContentViewModel {
        let feeAsset = walletAssets.first { $0.isFeeAsset }
        let assetInfo = assetManager.assetInfo(for: feeAsset?.identifier ?? "")
        return ActivityContentViewModel(txHash: transaction.base.txHash,
                                        title: SubmittedTransaction.title,
                                        subtitle: transaction.outcome.explanation,
                                        typeTransactionImage: R.image.wallet.send(),
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: assetInfo?.icon ?? ""),
                                        fiatText: "",
                                        status: transaction.base.status)
    }

    func transferTransactionViewModel(from transaction: TransferTransaction) -> ActivityContentViewModel {
        let asset = walletAssets.first(where: { $0.identifier == transaction.tokenId })
        let assetInfo = assetManager.assetInfo(for: asset?.identifier ?? "")
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let firstBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = transaction.transferType == .incoming ? "+ \(firstBalance) \(assetInfo?.symbol ?? "")" : "\(firstBalance) \(assetInfo?.symbol ?? "")"
        let textReversed = transaction.transferType == .incoming ? "\(assetInfo?.symbol ?? "") \(firstBalance) +" : "\(assetInfo?.symbol ?? "") \(firstBalance)"
        let textColor: SoramitsuColor = transaction.transferType == .incoming ? .statusSuccess : .fgPrimary
        let firstBalanceText = SoramitsuTextItem(text: isRTL ? textReversed : text,
                                                 fontData: FontType.textM,
                                                 textColor: textColor,
                                                 alignment: isRTL ? .left : .right)
        
        return ActivityContentViewModel(txHash: transaction.base.txHash,
                                        title: transaction.transferType.title,
                                        subtitle: transaction.peer,
                                        typeTransactionImage: transaction.transferType.image,
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: assetInfo?.icon ?? ""),
                                        firstBalanceText: firstBalanceText,
                                        fiatText: "",
                                        status: transaction.base.status)
    }
    
    func swapTransactionViewModel(from swap: Swap) -> ActivityContentViewModel {
        var fromAsset = walletAssets.first(where: { $0.identifier == swap.fromTokenId  })
        if fromAsset == nil {
            let fromAssetId = swap.fromTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            fromAsset = walletAssets.first(where: { $0.identifier == fromAssetId  })
        }
        
        var toAsset = walletAssets.first(where: { $0.identifier == swap.toTokenId  })
        if toAsset == nil {
            let toAssetId = swap.toTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            toAsset = walletAssets.first(where: { $0.identifier == toAssetId  })
        }
        
        let fromAssetInfo = assetManager.assetInfo(for: fromAsset?.identifier ?? "")
        let toAssetInfo = assetManager.assetInfo(for: toAsset?.identifier ?? "")
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let fromBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(swap.fromAmount.decimalValue) ?? ""
        let fromBalanceText = SoramitsuTextItem(text: isRTL ? "\(fromAsset?.symbol ?? "") \(fromBalance)" : "\(fromBalance) \(fromAsset?.symbol ?? "")",
                                                fontData: FontType.textM,
                                                textColor: .fgPrimary,
                                                alignment: isRTL ? .left : .right)
        let arrowText = SoramitsuTextItem(text: isRTL ? " ← " : " → ",
                                                fontData: FontType.textM,
                                                textColor: .fgPrimary,
                                                alignment: isRTL ? .left : .right)
        
        let toBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(swap.toAmount.decimalValue) ?? ""
        let toBalanceText = SoramitsuTextItem(text: isRTL ? "\(toAssetInfo?.symbol ?? "") \(toBalance)" : "\(toBalance) \(toAssetInfo?.symbol ?? "")",
                                              fontData: FontType.textM,
                                              textColor: .statusSuccess,
                                              alignment: isRTL ? .left : .right)

        let balanceText: SoramitsuAttributedText = isRTL ? [ toBalanceText, arrowText, fromBalanceText ] : [ fromBalanceText, arrowText, toBalanceText ]
        
        let subtitle = isRTL ? "\(toAsset?.symbol ?? "") ← \(fromAsset?.symbol ?? "")" : "\(fromAsset?.symbol ?? "") → \(toAsset?.symbol ?? "")"
        
        return ActivityContentViewModel(txHash: swap.base.txHash,
                                        title: R.string.localizable.polkaswapSwapped(preferredLanguages: .currentLocale),
                                        subtitle: subtitle,
                                        typeTransactionImage: R.image.wallet.swap(),
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: fromAssetInfo?.icon ?? ""),
                                        secondAssetImageViewModel: RemoteSerializer.shared.image(with: toAssetInfo?.icon ?? ""),
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: swap.base.status,
                                        isNeedTwoImage: true)
    }
    
    func liquidityTransactionViewModel(from liquidity: Liquidity) -> ActivityContentViewModel {
        var fromAsset = walletAssets.first(where: { $0.identifier == liquidity.firstTokenId  })
        if fromAsset == nil {
            let fromAssetId = liquidity.firstTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            fromAsset = walletAssets.first(where: { $0.identifier == fromAssetId  })
        }
        
        var toAsset = walletAssets.first(where: { $0.identifier == liquidity.secondTokenId })
        if toAsset == nil {
            let toAssetId = liquidity.secondTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            toAsset = walletAssets.first(where: { $0.identifier == toAssetId  })
        }
        
        let fromAssetInfo = assetManager.assetInfo(for: fromAsset?.identifier ?? "")
        let toAssetInfo = assetManager.assetInfo(for: toAsset?.identifier ?? "")
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let textColor: SoramitsuColor = liquidity.type == .add ? .fgPrimary : .statusSuccess
        let fromBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(liquidity.firstAmount.decimalValue) ?? ""
        let fromText = liquidity.type == .withdraw ? "+ \(fromBalance) \(fromAsset?.symbol ?? "")" : "\(fromBalance) \(fromAsset?.symbol ?? "")"
        let fromTextReversed = liquidity.type == .withdraw ? "\(fromAsset?.symbol ?? "") \(fromBalance) +" : "\(fromAsset?.symbol ?? "") \(fromBalance)"
        let fromBalanceText = SoramitsuTextItem(text: isRTL ? fromTextReversed : fromText,
                                                fontData: FontType.textM,
                                                textColor: textColor,
                                                alignment: isRTL ? .left : .right)
        
        let slashText = SoramitsuTextItem(text: " / ",
                                                fontData: FontType.textM,
                                                textColor: textColor,
                                                alignment: isRTL ? .left : .right)
        
        let toBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(liquidity.secondAmount.decimalValue) ?? ""
        let toText = liquidity.type == .withdraw ? "+ \(toBalance) \(toAssetInfo?.symbol ?? "")" : "\(toBalance) \(toAssetInfo?.symbol ?? "")"
        let toTextReversed = liquidity.type == .withdraw ? "\(toAssetInfo?.symbol ?? "") \(toBalance) +" : "\(toAssetInfo?.symbol ?? "") \(toBalance)"
        let toBalanceText = SoramitsuTextItem(text: isRTL ? toTextReversed : toText,
                                              fontData: FontType.textM,
                                              textColor: textColor,
                                              alignment: isRTL ? .left : .right)
        
        let balanceText: SoramitsuAttributedText = isRTL ? [ toBalanceText, slashText, fromBalanceText ] : [ fromBalanceText, slashText, toBalanceText ]
        
        let title = R.string.localizable.activityPoolTitle(preferredLanguages: .currentLocale)
        let subtitle = isRTL ? "\(toAsset?.symbol ?? "") / \(fromAsset?.symbol ?? "")" : "\(fromAsset?.symbol ?? "") / \(toAsset?.symbol ?? "")"
        
        return ActivityContentViewModel(txHash: liquidity.base.txHash,
                                        title: title,
                                        subtitle: subtitle,
                                        typeTransactionImage: liquidity.type.image,
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: fromAssetInfo?.icon ?? ""),
                                        secondAssetImageViewModel: RemoteSerializer.shared.image(with: toAssetInfo?.icon ?? ""),
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: liquidity.base.status,
                                        isNeedTwoImage: true)
    }
    
    func bondTransactionViewModel(from bond: ReferralBondTransaction) -> ActivityContentViewModel {
        let assetInfo = assetManager.assetInfo(for: bond.tokenId)
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let textColor: SoramitsuColor = bond.type == .unbond ? .statusSuccess : .fgPrimary
        let balance = NumberFormatter.cryptoAmounts.stringFromDecimal(bond.amount.decimalValue) ?? ""
        let text = bond.type == .unbond ? "+ \(balance) \(assetInfo?.symbol ?? "")" : "\(balance) \(assetInfo?.symbol ?? "")"
        let textReversed = bond.type == .unbond ? "\(assetInfo?.symbol ?? "") \(balance) +" : "\(assetInfo?.symbol ?? "") \(balance)"
        let balanceText = SoramitsuTextItem(text: isRTL ? textReversed : text,
                                                fontData: FontType.textM,
                                                textColor: textColor,
                                                alignment: isRTL ? .left : .right)
        
        return ActivityContentViewModel(txHash: bond.base.txHash,
                                        title: bond.type.detailsTitle,
                                        subtitle: SelectedWalletSettings.shared.currentAccount?.address ?? "",
                                        typeTransactionImage: bond.type.image,
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: assetInfo?.icon ?? ""),
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: bond.base.status,
                                        isNeedTwoImage: false)
    }
    
    func setReferrerTransactionViewModel(from setReferrer: SetReferrerTransaction) -> ActivityContentViewModel {
        let assetInfo = assetManager.assetInfo(for: setReferrer.tokenId)
        
        var symbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let invitationText = R.string.localizable.activityInvitationCount("1", preferredLanguages: .currentLocale)
        let balanceText = SoramitsuTextItem(text: setReferrer.isMyReferrer ? "--" : invitationText,
                                            fontData: FontType.textM,
                                            textColor: .fgPrimary,
                                            alignment: isRTL ? .left : .right)
        let title = setReferrer.isMyReferrer ? R.string.localizable.referrerSet(preferredLanguages: .currentLocale) : "Referral joined"
        let subtitle = setReferrer.isMyReferrer ? SelectedWalletSettings.shared.currentAccount?.address ?? "" : setReferrer.who 
        return ActivityContentViewModel(txHash: setReferrer.base.txHash,
                                        title: title,
                                        subtitle: subtitle,
                                        typeTransactionImage: R.image.wallet.send(),
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: assetInfo?.icon ?? ""),
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: setReferrer.base.status,
                                        isNeedTwoImage: false)
    }
    
    func claimRewardTransactionViewModel(from transaction: ClaimReward) -> ActivityContentViewModel {
        let asset = walletAssets.first(where: { $0.identifier == transaction.rewardTokenId })
        let assetInfo = assetManager.assetInfo(for: asset?.identifier ?? "")
        
        var symbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let firstBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = "+ \(firstBalance) \(assetInfo?.symbol ?? "")"
        let textReversed = "\(assetInfo?.symbol ?? "") \(firstBalance) +"
        let firstBalanceText = SoramitsuTextItem(text: isRTL ? textReversed : text,
                                                 fontData: FontType.textM,
                                                 textColor: .statusSuccess,
                                                 alignment: isRTL ? .left : .right)
        
        return ActivityContentViewModel(txHash: transaction.base.txHash,
                                        title: R.string.localizable.demeterClaimedReward(preferredLanguages: .currentLocale),
                                        subtitle: R.string.localizable.exploreDemeterTitle(preferredLanguages: .currentLocale),
                                        typeTransactionImage: R.image.wallet.claimStar(),
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: assetInfo?.icon ?? ""),
                                        firstBalanceText: firstBalanceText,
                                        fiatText: "",
                                        status: transaction.base.status)
    }
    
    func farmLiquidityTransactionViewModel(from transaction: FarmLiquidity) -> ActivityContentViewModel {
        let baseAsset = walletAssets.first(where: { $0.identifier == transaction.firstTokenId })
        let baseAssetInfo = assetManager.assetInfo(for: baseAsset?.identifier ?? "")
        
        let poolAsset = walletAssets.first(where: { $0.identifier == transaction.secondTokenId })
        let poolAssetInfo = assetManager.assetInfo(for: poolAsset?.identifier ?? "")
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let firstBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = "\(firstBalance) \(baseAsset?.symbol ?? "")-\(poolAsset?.symbol ?? "")"
        let textReversed = "\(poolAsset?.symbol ?? "")-\(baseAsset?.symbol ?? "") \(firstBalance)"
        let firstBalanceText = SoramitsuTextItem(text: isRTL ? textReversed : text,
                                                 fontData: FontType.textM,
                                                 textColor: .fgPrimary,
                                                 alignment: isRTL ? .left : .right)
        
        return ActivityContentViewModel(txHash: transaction.base.txHash,
                                        title: transaction.type.subtitle,
                                        subtitle: R.string.localizable.exploreDemeterTitle(preferredLanguages: .currentLocale),
                                        typeTransactionImage: transaction.type.image,
                                        firstAssetImageViewModel: RemoteSerializer.shared.image(with: baseAssetInfo?.icon ?? ""),
                                        secondAssetImageViewModel: RemoteSerializer.shared.image(with: poolAssetInfo?.icon ?? ""),
                                        firstBalanceText: firstBalanceText,
                                        fiatText: "",
                                        status: transaction.base.status,
                                        isNeedTwoImage: true)
    }
}
