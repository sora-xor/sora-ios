/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

final class WalletDescriptionInputValidatorFactory: WalletInputValidatorFactoryProtocol {
    func createTransferDescriptionValidator() -> WalletInputValidatorProtocol? {
        let maxLength: UInt8 = 64
        let hint = R.string.localizable.walletTransferDescriptionHint("\(maxLength)")
        return WalletDefaultInputValidator(hint: hint, maxLength: maxLength)
    }

    func createWithdrawDescriptionValidator(optionId: String) -> WalletInputValidatorProtocol? {
        return WalletDefaultInputValidator.ethereumAddress
    }
}
