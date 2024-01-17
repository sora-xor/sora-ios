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

import UIKit
import SoraUIKit
import CommonWallet

protocol ActivityDetailsViewModelProtocol: SoramitsuTableViewPaginationHandlerProtocol {
    func updateContent(completion: ([SoramitsuTableViewItemProtocol]) -> Void)
    func dismiss()
}

final class ActivityDetailsViewModel {
    var setupItem: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    var items: [SoramitsuTableViewItemProtocol] = []
    let model: Transaction
    let assetManager: AssetManagerProtocol
    let detailsFactory: ActivityDetailsViewModelFactoryProtocol
    let historyService: HistoryServiceProtocol
    var wireframe: ActivityDetailsWireframeProtocol?
    var assetId: String = ""
    weak var view: ActivityDetailsViewProtocol?
    var completion: (() -> Void)?
    private var appEventService = AppEventService()
    private let lpServiceFee: LPFeeServiceProtocol
    
    init(model: Transaction,
         wireframe: ActivityDetailsWireframeProtocol?,
         assetManager: AssetManagerProtocol,
         detailsFactory: ActivityDetailsViewModelFactoryProtocol,
         historyService: HistoryServiceProtocol,
         lpServiceFee: LPFeeServiceProtocol) {
        self.model = model
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.historyService = historyService
        self.lpServiceFee = lpServiceFee
        EventCenter.shared.add(observer: self)
    }
    
    func networkFeeInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func swapFeeInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapLiquidityTotalFeeDesc(preferredLanguages: .currentLocale),
            title: R.string.localizable.polkaswapLiquidityTotalFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }

}

extension ActivityDetailsViewModel: ActivityDetailsViewModelProtocol {
    func updateContent(completion: ([SoramitsuTableViewItemProtocol]) -> Void) {
        var items: [SoramitsuTableViewItemProtocol] = []
        
        if let headerItem = createHeaderActivityDetailsViewModel(with: model) {
            items.append(headerItem)
            items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        }
        
        if let detailsItem = createDetailsActivityDetailsViewModel(with: model) {
            detailsItem.copyToClipboardHander = { [weak self] value in
                let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
                let viewModel = AppEventViewController.ViewModel(title: title)
                let appEventController = AppEventViewController(style: .custom(viewModel))
                self?.appEventService.showToasterIfNeeded(viewController: appEventController)
                UIPasteboard.general.string = value
            }
            items.append(detailsItem)
            items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        }
        
        let buttonTitle = SoramitsuTextItem(text: R.string.localizable.commonClose(preferredLanguages: .currentLocale),
                                            fontData: FontType.buttonM,
                                            textColor: .accentTertiary,
                                            alignment: .center)
        items.append(SoramitsuButtonItem(title: buttonTitle, buttonBackgroudColor: .bgSurface, handler: { [weak self] in
            self?.view?.controller.dismiss(animated: true, completion: self?.completion)
        }))
        
        self.items = items
        completion(items)
    }
    
    func dismiss() {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}

extension ActivityDetailsViewModel: EventVisitorProtocol {
    
    func processNewTransaction(event: WalletNewTransactionInserted) {
        if let transaction = event.items.first, self.model.base.txHash == transaction.extrinsicHash.toHex(includePrefix: true) {
            
            var updatedModel = model
            updatedModel.base.status = transaction.processingResult.isSuccess ? .success : .failed
            if let headerItem = createHeaderActivityDetailsViewModel(with: updatedModel) {
                (self.items[0] as? HeaderActivityDetailsItem)?.details = headerItem.details
            }
            
            self.view?.update(items: self.items)
        }
    }
}

extension ActivityDetailsViewModel {
    private func createHeaderActivityDetailsViewModel(with transaction: Transaction) -> HeaderActivityDetailsItem? {
        if let transferTransaction = transaction as? TransferTransaction {
            assetId = transferTransaction.tokenId
            return headerTransferTransactionViewModel(from: transferTransaction)
        }
        
        if let swapTransaction = transaction as? Swap {
            assetId = swapTransaction.fromTokenId
            return headerSwapTransactionViewModel(from: swapTransaction)
        }
        
        if let liquidityTransaction = transaction as? Liquidity {
            assetId = liquidityTransaction.firstTokenId
            return headerLiquidityTransactionViewModel(from: liquidityTransaction)
        }
        
        if let bondTransaction = transaction as? ReferralBondTransaction {
            assetId = bondTransaction.tokenId
            return headerBondTransactionViewModel(from: bondTransaction)
        }
        
        if let setReferrerTransaction = transaction as? SetReferrerTransaction {
            assetId = setReferrerTransaction.tokenId
            return headerSetReferrerTransactionViewModel(from: setReferrerTransaction)
        }
        
        if let transferTransaction = transaction as? ClaimReward {
            assetId = transferTransaction.rewardTokenId
            return claimRewardTransactionViewModel(from: transferTransaction)
        }
        
        if let transferTransaction = transaction as? FarmLiquidity {
            assetId = transferTransaction.rewardTokenId
            return farmLiquidityTransactionViewModel(from: transferTransaction)
        }
        
        return nil
    }
    
    func headerTransferTransactionViewModel(from transaction: TransferTransaction) -> HeaderActivityDetailsItem {
        let assetInfo = assetManager.assetInfo(for: transaction.tokenId)
        
        var symbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let firstBalance = NumberFormatter.historyAmount.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = transaction.transferType == .incoming ? "+ \(firstBalance) \(assetInfo?.symbol ?? "")" : "\(firstBalance) \(assetInfo?.symbol ?? "")"
        let textColor: SoramitsuColor = transaction.transferType == .incoming ? .statusSuccess : .fgPrimary
        let firstBalanceText = SoramitsuTextItem(text: text,
                                                 fontData: FontType.headline3,
                                                 textColor: textColor,
                                                 alignment: .center)
        let isHideFeeDetails = transaction.transferType == .incoming
        let details = detailsFactory.createHeaderActivityDetailsViewModels(
            transactionBase: transaction.base,
            isHideFeeDetails: isHideFeeDetails
        ) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
        
        return HeaderActivityDetailsItem(typeText: transaction.transferType.detailsTitle,
                                         typeTransactionImage: transaction.transferType.image,
                                         firstAssetImageViewModel: symbolViewModel,
                                         firstBalanceText: firstBalanceText.attributedString,
                                         details: details)
    }
    
    func claimRewardTransactionViewModel(from transaction: ClaimReward) -> HeaderActivityDetailsItem {
        let assetInfo = assetManager.assetInfo(for: transaction.rewardTokenId)
        
        var symbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let firstBalance = NumberFormatter.historyAmount.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = "+ \(firstBalance) \(assetInfo?.symbol ?? "")"
        let firstBalanceText = SoramitsuTextItem(text: text,
                                                 fontData: FontType.headline3,
                                                 textColor: .statusSuccess,
                                                 alignment: .center)
        let details = detailsFactory.createHeaderActivityDetailsViewModels(transactionBase: transaction.base, isHideFeeDetails: false) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
        
        return HeaderActivityDetailsItem(typeText: R.string.localizable.demeterClaimedReward(preferredLanguages: .currentLocale),
                                         typeTransactionImage: R.image.wallet.claimStar(),
                                         firstAssetImageViewModel: symbolViewModel,
                                         firstBalanceText: firstBalanceText.attributedString,
                                         details: details)
    }
    
    func farmLiquidityTransactionViewModel(from transaction: FarmLiquidity) -> HeaderActivityDetailsItem {
        let baseAssetInfo = assetManager.assetInfo(for: transaction.firstTokenId)
        var baseSymbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = baseAssetInfo?.icon {
            baseSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let poolAssetInfo = assetManager.assetInfo(for: transaction.secondTokenId)
        var poolSymbolViewModel: WalletImageViewModelProtocol?
        
        if let iconString = poolAssetInfo?.icon {
            poolSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let firstBalance = NumberFormatter.historyAmount.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = "\(firstBalance) \(baseAssetInfo?.symbol ?? "")-\(poolAssetInfo?.symbol ?? "")"
        let firstBalanceText = SoramitsuTextItem(text: text,
                                                 fontData: FontType.headline3,
                                                 textColor: .fgPrimary,
                                                 alignment: .center)
        let details = detailsFactory.createHeaderActivityDetailsViewModels(transactionBase: transaction.base, isHideFeeDetails: false) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
        
        return HeaderActivityDetailsItem(typeText: transaction.type.subtitle,
                                         typeTransactionImage: transaction.type.image,
                                         firstAssetImageViewModel: baseSymbolViewModel,
                                         secondAssetImageViewModel: poolSymbolViewModel,
                                         firstBalanceText: firstBalanceText.attributedString,
                                         details: details)
    }
    
    func headerSwapTransactionViewModel(from swap: Swap) -> HeaderActivityDetailsItem {
        let fromAssetInfo = assetManager.assetInfo(for: swap.fromTokenId)
        let toAssetInfo = assetManager.assetInfo(for: swap.toTokenId)
        
        var fromSymbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = fromAssetInfo?.icon {
            fromSymbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        var toSymbolViewModel: WalletImageViewModelProtocol?
        if let toIconString = toAssetInfo?.icon {
            toSymbolViewModel = WalletSvgImageViewModel(svgString: toIconString)
        }
        
        let fromBalance = NumberFormatter.historyAmount.stringFromDecimal(swap.fromAmount.decimalValue) ?? ""
        let fromBalanceText = SoramitsuTextItem(text: "\(fromBalance) \(fromAssetInfo?.symbol ?? "")",
                                                fontData: FontType.headline3,
                                                textColor: .fgPrimary,
                                                alignment: .right)
        
        let toBalance = NumberFormatter.historyAmount.stringFromDecimal(swap.toAmount.decimalValue) ?? ""
        let toBalanceText = SoramitsuTextItem(text: "\(toBalance) \(toAssetInfo?.symbol ?? "")",
                                              fontData: FontType.headline3,
                                              textColor: .statusSuccess,
                                              alignment: .right)
        
        let details = detailsFactory.createHeaderSwapActivityDetailsViewModels(
            transaction: swap,
            networkFeeTapHandler: { [weak self] in
                self?.networkFeeInfoButtonTapped()
            }, lpFeeTapHandler: { [weak self] in
                self?.swapFeeInfoButtonTapped()
            })
        
        return HeaderActivityDetailsItem(typeText: R.string.localizable.polkaswapSwapped(preferredLanguages: .currentLocale),
                                         typeTransactionImage: R.image.wallet.swap(),
                                         actionTransactionImage: R.image.wallet.arrow(),
                                         firstAssetImageViewModel: fromSymbolViewModel,
                                         secondAssetImageViewModel: toSymbolViewModel,
                                         firstBalanceText: fromBalanceText.attributedString,
                                         secondBalanceText: toBalanceText.attributedString,
                                         details: details)
    }
    
    func headerLiquidityTransactionViewModel(from liquidity: Liquidity) -> HeaderActivityDetailsItem {
        let fromAssetInfo = assetManager.assetInfo(for: liquidity.firstTokenId)
        let toAssetInfo = assetManager.assetInfo(for: liquidity.secondTokenId)
        
        var fromSymbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = fromAssetInfo?.icon {
            fromSymbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        var toSymbolViewModel: WalletImageViewModelProtocol?
        if let toIconString = toAssetInfo?.icon {
            toSymbolViewModel = WalletSvgImageViewModel(svgString: toIconString)
        }
        
        let textColor: SoramitsuColor = liquidity.type == .withdraw ? .statusSuccess : .fgPrimary
        let fromBalance = NumberFormatter.historyAmount.stringFromDecimal(liquidity.secondAmount.decimalValue) ?? ""
        let fromText = liquidity.type == .withdraw ? "+ \(fromBalance) \(fromAssetInfo?.symbol ?? "")" : "\(fromBalance) \(fromAssetInfo?.symbol ?? "")"
        let fromBalanceText = SoramitsuTextItem(text: fromText,
                                                fontData: FontType.headline3,
                                                textColor: textColor,
                                                alignment: .right)
        
        let toBalance = NumberFormatter.historyAmount.stringFromDecimal(liquidity.firstAmount.decimalValue) ?? ""
        let toText = liquidity.type == .withdraw ? "+ \(toBalance) \(toAssetInfo?.symbol ?? "")" : "\(toBalance) \(toAssetInfo?.symbol ?? "")"
        let toBalanceText = SoramitsuTextItem(text: toText,
                                              fontData: FontType.headline3,
                                              textColor: textColor,
                                              alignment: .right)
        
        let details = detailsFactory.createHeaderActivityDetailsViewModels(transactionBase: liquidity.base, isHideFeeDetails: false) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
        
        let title = liquidity.type == .add
            ? R.string.localizable.detailsSentToPool(preferredLanguages: .currentLocale)
            : R.string.localizable.detailsReceiveFromPool(preferredLanguages: .currentLocale)
        
        return HeaderActivityDetailsItem(typeText: title,
                                         typeTransactionImage: liquidity.type.image,
                                         actionTransactionImage: R.image.wallet.detailsPlus(),
                                         firstAssetImageViewModel: toSymbolViewModel,
                                         secondAssetImageViewModel: fromSymbolViewModel,
                                         firstBalanceText: toBalanceText.attributedString,
                                         secondBalanceText: fromBalanceText.attributedString,
                                         details: details)
    }
    
    func headerBondTransactionViewModel(from bond: ReferralBondTransaction) -> HeaderActivityDetailsItem {
        let assetInfo = assetManager.assetInfo(for: bond.tokenId)
        
        var symbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        let textColor: SoramitsuColor = bond.type == .unbond ? .statusSuccess : .fgPrimary
        let balance = NumberFormatter.historyAmount.stringFromDecimal(bond.amount.decimalValue) ?? ""
        let text = bond.type == .unbond ? "+ \(balance) \(assetInfo?.symbol ?? "")" : "\(balance) \(assetInfo?.symbol ?? "")"
        let balanceText = SoramitsuTextItem(text: text,
                                            fontData: FontType.headline3,
                                            textColor: textColor,
                                            alignment: .right)
        
        let details = detailsFactory.createHeaderActivityDetailsViewModels(transactionBase: bond.base, isHideFeeDetails: false) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
        
        return HeaderActivityDetailsItem(typeText: bond.type.detailsTitle,
                                         typeTransactionImage: bond.type.image,
                                         firstAssetImageViewModel: symbolViewModel,
                                         firstBalanceText: balanceText.attributedString,
                                         details: details)
    }
    
    func headerSetReferrerTransactionViewModel(from setReferrer: SetReferrerTransaction) -> HeaderActivityDetailsItem {
        let assetInfo = assetManager.assetInfo(for: setReferrer.tokenId)
        
        var symbolViewModel: WalletImageViewModelProtocol?
        if let fromIconString = assetInfo?.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: fromIconString)
        }
        
        let balance = NumberFormatter.historyAmount.stringFromDecimal(setReferrer.base.fee.decimalValue) ?? ""
        let xorText = "\(balance) \(assetInfo?.symbol ?? "")"
        let invitationText = R.string.localizable.activityInvitationCount("1", preferredLanguages: .currentLocale)
        let balanceText = SoramitsuTextItem(text: setReferrer.isMyReferrer ? xorText : invitationText,
                                            fontData: FontType.headline3,
                                            textColor: .fgPrimary,
                                            alignment: .right)
        let title = setReferrer.isMyReferrer ? R.string.localizable.referrerSet(preferredLanguages: .currentLocale) : "Referral joined"
        
        let details = detailsFactory.createHeaderActivityDetailsViewModels(transactionBase: setReferrer.base,
                                                                           isHideFeeDetails: true) { [weak self] in
            self?.networkFeeInfoButtonTapped()
        }
        
        return HeaderActivityDetailsItem(typeText: title,
                                         typeTransactionImage: R.image.wallet.send(),
                                         firstAssetImageViewModel: symbolViewModel,
                                         firstBalanceText: balanceText.attributedString,
                                         details: details)
    }
    
    private func createDetailsActivityDetailsViewModel(with transaction: Transaction) -> ActivityDetailsItem? {
        if let transferTransaction = transaction as? TransferTransaction {
            return detailsTransferTransactionViewModel(from: transferTransaction)
        }
        
        if let swapTransaction = transaction as? Swap {
            return detailsCommonTransactionViewModel(from: swapTransaction)
        }
        
        if let liquidityTransaction = transaction as? Liquidity {
            return detailsCommonTransactionViewModel(from: liquidityTransaction)
        }
        
        if let bondTransaction = transaction as? ReferralBondTransaction {
            return detailsCommonTransactionViewModel(from: bondTransaction)
        }
        
        if let setReferrerTransaction = transaction as? SetReferrerTransaction {
            return detailsSetReffererTransactionViewModel(from: setReferrerTransaction)
        }
        
        if let transferTransaction = transaction as? ClaimReward {
            return detailsClaimRewardTransactionViewModel(from: transferTransaction)
        }
        
        if let transferTransaction = transaction as? FarmLiquidity {
            return detailsFarmLiquidityTransactionViewModel(from: transferTransaction)
        }
        
        return nil
    }
    
    func detailsTransferTransactionViewModel(from transfer: TransferTransaction) -> ActivityDetailsItem {
        var details: [ActivityDetailViewModel] = []
        
        if !transfer.base.txHash.isEmpty {
            let txHash = ActivityDetailViewModel(title: R.string.localizable.transactionHash(preferredLanguages: .currentLocale),
                                                 value: transfer.base.txHash)
            details.append(txHash)
        }

        if !transfer.base.blockHash.isEmpty {
            let blockHash = ActivityDetailViewModel(title: R.string.localizable.blockId(preferredLanguages: .currentLocale),
                                                    value: transfer.base.blockHash)
            details.append(blockHash)
        }
        
        let receiptValue = transfer.transferType == .incoming ? SelectedWalletSettings.shared.currentAccount?.address ?? "" : transfer.peer
        let receipt = ActivityDetailViewModel(title: R.string.localizable.commonRecipient(preferredLanguages: .currentLocale),
                                              value: receiptValue)
        details.append(receipt)
        
        let senderValue = transfer.transferType == .incoming ? transfer.peer : SelectedWalletSettings.shared.currentAccount?.address ?? ""
        let sender = ActivityDetailViewModel(title: R.string.localizable.commonSender(preferredLanguages: .currentLocale),
                                             value: senderValue)
        details.append(sender)
        
        return ActivityDetailsItem(detailViewModels: details)
    }
    
    func detailsClaimRewardTransactionViewModel(from transfer: ClaimReward) -> ActivityDetailsItem {
        var details: [ActivityDetailViewModel] = []
        
        if !transfer.base.txHash.isEmpty {
            let txHash = ActivityDetailViewModel(title: R.string.localizable.transactionHash(preferredLanguages: .currentLocale),
                                                 value: transfer.base.txHash)
            details.append(txHash)
        }

        if !transfer.base.blockHash.isEmpty {
            let blockHash = ActivityDetailViewModel(title: R.string.localizable.blockId(preferredLanguages: .currentLocale),
                                                    value: transfer.base.blockHash)
            details.append(blockHash)
        }
        
        let receipt = ActivityDetailViewModel(title: R.string.localizable.commonRecipient(preferredLanguages: .currentLocale),
                                              value: transfer.peer)
        details.append(receipt)
        
        return ActivityDetailsItem(detailViewModels: details)
    }
    
    func detailsFarmLiquidityTransactionViewModel(from transfer: FarmLiquidity) -> ActivityDetailsItem {
        var details: [ActivityDetailViewModel] = []
        
        if !transfer.base.txHash.isEmpty {
            let txHash = ActivityDetailViewModel(title: R.string.localizable.transactionHash(preferredLanguages: .currentLocale),
                                                 value: transfer.base.txHash)
            details.append(txHash)
        }

        if !transfer.base.blockHash.isEmpty {
            let blockHash = ActivityDetailViewModel(title: R.string.localizable.blockId(preferredLanguages: .currentLocale),
                                                    value: transfer.base.blockHash)
            details.append(blockHash)
        }
        
        let sender = ActivityDetailViewModel(title: R.string.localizable.commonSender(preferredLanguages: .currentLocale),
                                             value: transfer.sender)
        details.append(sender)
        
        return ActivityDetailsItem(detailViewModels: details)
    }
    
    
    func detailsSetReffererTransactionViewModel(from setReferrer: SetReferrerTransaction) -> ActivityDetailsItem {
        var details: [ActivityDetailViewModel] = []
        
        if !setReferrer.base.txHash.isEmpty {
            let txHash = ActivityDetailViewModel(title: R.string.localizable.transactionHash(preferredLanguages: .currentLocale),
                                                 value: setReferrer.base.txHash)
            details.append(txHash)
        }

        if !setReferrer.base.blockHash.isEmpty {
            let blockHash = ActivityDetailViewModel(title: R.string.localizable.blockId(preferredLanguages: .currentLocale),
                                                    value: setReferrer.base.blockHash)
            details.append(blockHash)
        }
        
        if setReferrer.isMyReferrer {
            let referrer = ActivityDetailViewModel(title: R.string.localizable.historyReferrer(preferredLanguages: .currentLocale),
                                                   value: setReferrer.who)
            details.append(referrer)
            
            let referral = ActivityDetailViewModel(title: R.string.localizable.commonSender(preferredLanguages: .currentLocale),
                                                   value: SelectedWalletSettings.shared.currentAccount?.address ?? "")
            details.append(referral)
        } else {
            let referral = ActivityDetailViewModel(title: R.string.localizable.commonSender(preferredLanguages: .currentLocale),
                                                   value: setReferrer.who)
            details.append(referral)
        }
        
        return ActivityDetailsItem(detailViewModels: details)
    }
    
    func detailsCommonTransactionViewModel(from transaction: Transaction) -> ActivityDetailsItem {
        var details: [ActivityDetailViewModel] = []
        
        if !transaction.base.txHash.isEmpty {
            let txHash = ActivityDetailViewModel(title: R.string.localizable.transactionHash(preferredLanguages: .currentLocale),
                                                 value: transaction.base.txHash)
            details.append(txHash)
        }

        if !transaction.base.blockHash.isEmpty {
            let blockHash = ActivityDetailViewModel(title: R.string.localizable.blockId(preferredLanguages: .currentLocale),
                                                    value: transaction.base.blockHash)
            details.append(blockHash)
        }
        
        let senderValue = SelectedWalletSettings.shared.currentAccount?.address ?? ""
        let sender = ActivityDetailViewModel(title: R.string.localizable.commonSender(preferredLanguages: .currentLocale),
                                             value: senderValue)
        details.append(sender)
        
        return ActivityDetailsItem(detailViewModels: details)
    }
}
