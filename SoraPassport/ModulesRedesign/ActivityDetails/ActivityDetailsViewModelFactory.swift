import Foundation
import CommonWallet
import SoraUIKit
import UIKit
import XNetworking
import SoraFoundation

protocol ActivityDetailsViewModelFactoryProtocol {
    func createHeaderActivityDetailsViewModels(transactionBase: TransactionBase,
                                               isHideFeeDetails: Bool,
                                               tapHandler: (() -> Void)?) -> [DetailViewModel]
    func createHeaderSwapActivityDetailsViewModels(transaction: Swap,
                                                   networkFeeTapHandler: (() -> Void)?,
                                                   lpFeeTapHandler: (() -> Void)?) -> [DetailViewModel]
}

final class ActivityDetailsViewModelFactory {
    let assetManager: AssetManagerProtocol
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM. YYYY, HH:mm"
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()
    
    init(assetManager: AssetManagerProtocol) {
        self.assetManager = assetManager
    }
}

extension ActivityDetailsViewModelFactory: ActivityDetailsViewModelFactoryProtocol {
    func createHeaderActivityDetailsViewModels(transactionBase: TransactionBase,
                                               isHideFeeDetails: Bool,
                                               tapHandler: (() -> Void)?) -> [DetailViewModel] {
        
        let statusText = SoramitsuTextItem(text: transactionBase.status.title,
                                           fontData: FontType.textS,
                                           textColor: transactionBase.status.color,
                                           alignment: .right)
        let statusViewModel = DetailViewModel(title: R.string.localizable.walletTxDetailsStatus(preferredLanguages: .currentLocale),
                                              statusAssetImage: transactionBase.status.image,
                                              assetAmountText: statusText)
        
        let date = Date(timeIntervalSince1970: TimeInterval(Double(transactionBase.timestamp) ?? 0))
        let dateText = SoramitsuTextItem(text: dateFormatter.string(from: date),
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let dateViewModel = DetailViewModel(title: R.string.localizable.transactionDate(preferredLanguages: .currentLocale),
                                              assetAmountText: dateText)
        
        let feeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(transactionBase.fee.decimalValue) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let feeItem = DetailViewModel(title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                                      assetAmountText: feeText)
        feeItem.infoHandler = tapHandler
        
        return transactionBase.fee.decimalValue == 0 || isHideFeeDetails ? [statusViewModel, dateViewModel] : [statusViewModel, dateViewModel, feeItem]
    }
    
    func createHeaderSwapActivityDetailsViewModels(transaction: Swap,
                                                   networkFeeTapHandler: (() -> Void)?,
                                                   lpFeeTapHandler: (() -> Void)?) -> [DetailViewModel] {
        var items = createHeaderActivityDetailsViewModels(
            transactionBase: transaction.base,
            isHideFeeDetails: false,
            tapHandler: networkFeeTapHandler
        )
        
        let lpFeeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(transaction.lpFee.decimalValue) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let lpFeeItem = DetailViewModel(title: R.string.localizable.polkaswapLiquidityTotalFee(preferredLanguages: .currentLocale),
                                      assetAmountText: lpFeeText)
        lpFeeItem.infoHandler = lpFeeTapHandler
        items.append(lpFeeItem)
        
        return items
    }
}


