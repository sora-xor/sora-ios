import Foundation
import CommonWallet
import SoraUIKit
import UIKit
import XNetworking
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
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter
    }()

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
        
        let firstBalance = formatter.stringFromDecimal(transaction.amount.decimalValue) ?? ""
        let text = transaction.transferType == .incoming ? "+ \(firstBalance) \(assetInfo?.symbol ?? "")" : "\(firstBalance) \(assetInfo?.symbol ?? "")"
        let textColor: SoramitsuColor = transaction.transferType == .incoming ? .statusSuccess : .fgPrimary
        let firstBalanceText = SoramitsuTextItem(text: text,
                                                 fontData: FontType.textM,
                                                 textColor: textColor,
                                                 alignment: .right)
        
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
        
        let fromBalance = formatter.stringFromDecimal(swap.fromAmount.decimalValue) ?? ""
        let fromBalanceText = SoramitsuTextItem(text: "\(fromBalance) \(fromAsset?.symbol ?? "")",
                                                fontData: FontType.textM,
                                                textColor: .fgPrimary,
                                                alignment: .right)
        let arrowText = SoramitsuTextItem(text: " → ",
                                                fontData: FontType.textM,
                                                textColor: .fgPrimary,
                                                alignment: .right)
        
        let toBalance = formatter.stringFromDecimal(swap.toAmount.decimalValue) ?? ""
        let toBalanceText = SoramitsuTextItem(text: "\(toBalance) \(toAssetInfo?.symbol ?? "")",
                                              fontData: FontType.textM,
                                              textColor: .statusSuccess,
                                              alignment: .right)

        let balanceText: SoramitsuAttributedText = [ fromBalanceText, arrowText, toBalanceText ]
        
        return ActivityContentViewModel(txHash: swap.base.txHash,
                                        title: R.string.localizable.polkaswapSwapped(preferredLanguages: .currentLocale),
                                        subtitle: "\(fromAsset?.symbol ?? "") → \(toAsset?.symbol ?? "")",
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
        
        let textColor: SoramitsuColor = liquidity.type == .add ? .fgPrimary : .statusSuccess
        let fromBalance = formatter.stringFromDecimal(liquidity.secondAmount.decimalValue) ?? ""
        let fromText = liquidity.type == .withdraw ? "+ \(fromBalance) \(fromAsset?.symbol ?? "")" : "\(fromBalance) \(fromAsset?.symbol ?? "")"
        let fromBalanceText = SoramitsuTextItem(text: fromText,
                                                fontData: FontType.textM,
                                                textColor: textColor,
                                                alignment: .right)
        
        let slashText = SoramitsuTextItem(text: " / ",
                                                fontData: FontType.textM,
                                                textColor: textColor,
                                                alignment: .right)
        
        let toBalance = formatter.stringFromDecimal(liquidity.firstAmount.decimalValue) ?? ""
        let toText = liquidity.type == .withdraw ? "+ \(toBalance) \(toAssetInfo?.symbol ?? "")" : "\(toBalance) \(toAssetInfo?.symbol ?? "")"
        let toBalanceText = SoramitsuTextItem(text: toText,
                                              fontData: FontType.textM,
                                              textColor: textColor,
                                              alignment: .right)
        
        let balanceText: SoramitsuAttributedText = [ toBalanceText, slashText, fromBalanceText ]
        
        let title = R.string.localizable.activityPoolTitle(preferredLanguages: .currentLocale)
        
        return ActivityContentViewModel(txHash: liquidity.base.txHash,
                                        title: title,
                                        subtitle: "\(toAsset?.symbol ?? "") / \(fromAsset?.symbol ?? "")",
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
        
        let textColor: SoramitsuColor = bond.type == .unbond ? .statusSuccess : .fgPrimary
        let balance = formatter.stringFromDecimal(bond.amount.decimalValue) ?? ""
        let text = bond.type == .unbond ? "+ \(balance) \(assetInfo?.symbol ?? "")" : "\(balance) \(assetInfo?.symbol ?? "")"
        let balanceText = SoramitsuTextItem(text: text,
                                                fontData: FontType.textM,
                                                textColor: textColor,
                                                alignment: .right)
        
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

        let invitationText = R.string.localizable.activityInvitationCount("1", preferredLanguages: .currentLocale)
        let balanceText = SoramitsuTextItem(text: setReferrer.isMyReferrer ? "--" : invitationText,
                                            fontData: FontType.textM,
                                            textColor: .fgPrimary,
                                            alignment: .right)
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
}
