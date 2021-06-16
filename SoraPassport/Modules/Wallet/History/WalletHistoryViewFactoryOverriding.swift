/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

final class WalletHistoryViewFactoryOverriding: HistoryViewFactoryOverriding {
    func createBackgroundView() -> BaseHistoryBackgroundView? {
        let backgroundView = WalletHistoryBackgroundView()
        return backgroundView
    }
}
