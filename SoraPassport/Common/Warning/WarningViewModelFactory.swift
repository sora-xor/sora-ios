//
//  WarningViewModelFactory.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 6/23/23.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation

final class WarningViewModelFactory {
    func insufficientBalanceViewModel(feeAssetSymbol: String, feeAmount: Decimal) -> WarningViewModel {
        let feeAmount = NumberFormatter.cryptoAssets.stringFromDecimal(feeAmount) ?? ""
        let title = R.string.localizable.commonTitleWarning(preferredLanguages: .currentLocale)
        let descriptionText = R.string.localizable.swapConfirmationScreenWarningBalanceAfterwardsTransactionIsTooSmall(feeAssetSymbol,
                                                                                                                       feeAmount,
                                                                                                                       preferredLanguages: .currentLocale)
        return WarningViewModel(title: title, descriptionText: descriptionText, isHidden: true)
    }
}
