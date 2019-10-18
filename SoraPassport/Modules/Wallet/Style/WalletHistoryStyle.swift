/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

extension HistoryViewStyle {
    static var sora: HistoryViewStyleProtocol {
        let borderStyle = WalletStrokeStyle(color: .clear, lineWidth: 0.0)
        let cornerRadius: CGFloat = 10.0
        let titleStyle = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 15.0)!,
                                         color: UIColor(white: 44.0 / 255.0, alpha: 1.0))

        return HistoryViewStyle(fillColor: .white,
                                borderStyle: borderStyle,
                                cornerRadius: cornerRadius,
                                titleStyle: titleStyle,
                                filterIcon: nil,
                                closeIcon: nil,
                                panIndicatorStyle: UIColor(white: 221.0 / 255.0, alpha: 1.0))
    }
}
