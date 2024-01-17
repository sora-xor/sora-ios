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
import CommonWallet
import SoraUIKit
import UIKit
import sorawallet
import SoraFoundation

protocol ActivityViewModelFactoryProtocol {
    var currentDate: Date? { get set } 
    func createActivityViewModels(with transactions: [Transaction],
                                  tapHandler: @escaping (Transaction) -> Void) -> [SoramitsuTableViewItemProtocol]
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
                                  tapHandler: @escaping (Transaction) -> Void) -> [SoramitsuTableViewItemProtocol] {
        var models: [SoramitsuTableViewItemProtocol] = []
        
        transactions.forEach { transaction in
            let transactionDate = Date(timeIntervalSince1970: Double(transaction.base.timestamp) ?? 0)
            
            let dateOrder = Calendar.current.compare(transactionDate, to: currentDate ?? Date(), toGranularity: .day)
            
            if currentDate == nil || dateOrder != .orderedSame {
                let dateFormatter = EventListDateFormatterFactory.createDateFormatter()
                dateFormatter.locale = LocalizationManager.shared.selectedLocale
                let dateText = dateFormatter.string(from: transactionDate)
                let dateItem = ActivityDateItem(text: dateText)
                models.append(dateItem)
                currentDate = transactionDate
                
                
                if let transactionModel = createActivityViewModel(with: transaction) {
                    let activityModel = ActivityItem(model: transactionModel)
                    activityModel.handler = {
                        tapHandler(transaction)
                    }
                    models.append(activityModel)
                }
            } else {
                if let transactionModel = createActivityViewModel(with: transaction) {
                    let activityModel = ActivityItem(model: transactionModel)
                    activityModel.handler = {
                        tapHandler(transaction)
                    }
                    models.append(activityModel)
                }
            }
        }
        
        return models
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
        
        return nil
    }
}

private extension ActivityViewModelFactory {
    func transferTransactionViewModel(from transaction: TransferTransaction) -> ActivityContentViewModel {
        let asset = walletAssets.first(where: { $0.identifier == transaction.tokenId }) ?? walletAssets.first { $0.isFeeAsset }
        let assetInfo = assetManager.assetInfo(for: asset?.identifier ?? "")
        
        var symbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
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
                                        firstAssetImageViewModel: symbolViewModel,
                                        firstBalanceText: firstBalanceText,
                                        fiatText: "",
                                        status: transaction.base.status)
    }
    
    func swapTransactionViewModel(from swap: Swap) -> ActivityContentViewModel {
        var fromAsset = walletAssets.first(where: { $0.identifier == swap.fromTokenId  })
        if fromAsset == nil {
            let fromAssetId = swap.fromTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            fromAsset = walletAssets.first(where: { $0.identifier == fromAssetId  }) ?? walletAssets.first { $0.isFeeAsset }
        }
        
        var toAsset = walletAssets.first(where: { $0.identifier == swap.toTokenId  })
        if toAsset == nil {
            let toAssetId = swap.toTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            toAsset = walletAssets.first(where: { $0.identifier == toAssetId  }) ?? walletAssets.first { $0.isFeeAsset }
        }
        
        let fromAssetInfo = assetManager.assetInfo(for: fromAsset?.identifier ?? "")
        let toAssetInfo = assetManager.assetInfo(for: toAsset?.identifier ?? "")
        
        var fromSymbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = fromAssetInfo?.icon {
            fromSymbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        var toSymbolViewModel: WalletImageViewModelProtocol?
        if let toIconString = toAssetInfo?.icon {
            toSymbolViewModel = WalletSvgImageViewModel(svgString: toIconString)
        }
        
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
                                        firstAssetImageViewModel: fromSymbolViewModel,
                                        secondAssetImageViewModel: toSymbolViewModel,
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: swap.base.status,
                                        isNeedTwoImage: true)
    }
    
    func liquidityTransactionViewModel(from liquidity: Liquidity) -> ActivityContentViewModel {
        var fromAsset = walletAssets.first(where: { $0.identifier == liquidity.firstTokenId  })
        if fromAsset == nil {
            let fromAssetId = liquidity.firstTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            fromAsset = walletAssets.first(where: { $0.identifier == fromAssetId  }) ?? walletAssets.first { $0.isFeeAsset }
        }
        
        var toAsset = walletAssets.first(where: { $0.identifier == liquidity.secondTokenId })
        if toAsset == nil {
            let toAssetId = liquidity.secondTokenId.replacingOccurrences(of: "{\"code\":\"", with: "").replacingOccurrences(of: "\"}", with: "")
            toAsset = walletAssets.first(where: { $0.identifier == toAssetId  }) ?? walletAssets.first { $0.isFeeAsset }
        }
        
        let fromAssetInfo = assetManager.assetInfo(for: fromAsset?.identifier ?? "")
        let toAssetInfo = assetManager.assetInfo(for: toAsset?.identifier ?? "")
        
        var fromSymbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = fromAssetInfo?.icon {
            fromSymbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        var toSymbolViewModel: WalletImageViewModelProtocol?
        if let toIconString = toAssetInfo?.icon {
            toSymbolViewModel = WalletSvgImageViewModel(svgString: toIconString)
        }
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let textColor: SoramitsuColor = liquidity.type == .add ? .fgPrimary : .statusSuccess
        let fromBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(liquidity.secondAmount.decimalValue) ?? ""
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
        
        let toBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(liquidity.firstAmount.decimalValue) ?? ""
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
                                        firstAssetImageViewModel: toSymbolViewModel,
                                        secondAssetImageViewModel: fromSymbolViewModel,
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: liquidity.base.status,
                                        isNeedTwoImage: true)
    }
    
    func bondTransactionViewModel(from bond: ReferralBondTransaction) -> ActivityContentViewModel {
        let assetInfo = assetManager.assetInfo(for: bond.tokenId)
        
        var symbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
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
                                        firstAssetImageViewModel: symbolViewModel,
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
                                        firstAssetImageViewModel: symbolViewModel,
                                        firstBalanceText: balanceText,
                                        fiatText: "",
                                        status: setReferrer.base.status,
                                        isNeedTwoImage: false)
    }
    
    func claimRewardTransactionViewModel(from transaction: ClaimReward) -> ActivityContentViewModel {
        let asset = walletAssets.first(where: { $0.identifier == transaction.rewardTokenId }) ?? walletAssets.first { $0.isFeeAsset }
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
                                        firstAssetImageViewModel: symbolViewModel,
                                        firstBalanceText: firstBalanceText,
                                        fiatText: "",
                                        status: transaction.base.status)
    }
    
    func farmLiquidityTransactionViewModel(from transaction: FarmLiquidity) -> ActivityContentViewModel {
        let baseAsset = walletAssets.first(where: { $0.identifier == transaction.firstTokenId }) ?? walletAssets.first { $0.isFeeAsset }
        let baseAssetInfo = assetManager.assetInfo(for: baseAsset?.identifier ?? "")
        
        var baseSymbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = baseAssetInfo?.icon {
            baseSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let poolAsset = walletAssets.first(where: { $0.identifier == transaction.secondTokenId }) ?? walletAssets.first { $0.isFeeAsset }
        let poolAssetInfo = assetManager.assetInfo(for: poolAsset?.identifier ?? "")
        
        var poolSymbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = poolAssetInfo?.icon {
            poolSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
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
                                        firstAssetImageViewModel: baseSymbolViewModel,
                                        secondAssetImageViewModel: poolSymbolViewModel,
                                        firstBalanceText: firstBalanceText,
                                        fiatText: "",
                                        status: transaction.base.status,
                                        isNeedTwoImage: true)
    }
}
