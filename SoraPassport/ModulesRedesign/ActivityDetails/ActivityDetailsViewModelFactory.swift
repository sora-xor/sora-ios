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
import BigInt

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
    
    let localizationManager = LocalizationManager.shared
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = LocalizationManager.shared.dateFormat
        formatter.locale = !LocalizationManager.shared.isArabic ? LocalizationManager.shared.selectedLocale : nil
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
        
        let feeDecimal = Decimal.fromSubstrateAmount(BigUInt(transactionBase.fee.stringValue) ?? BigUInt(0), precision: 18) ?? Decimal(0)
        let fee = "\(NumberFormatter.cryptoAssets.stringFromDecimal(feeDecimal) ?? "") XOR"
        let feeReversed = "XOR \(NumberFormatter.cryptoAssets.stringFromDecimal(feeDecimal) ?? "")"
        
        let feeText = SoramitsuTextItem(text: localizationManager.isRightToLeft ? feeReversed : fee,
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
        
        return items
    }
}


