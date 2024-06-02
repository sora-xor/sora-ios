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


