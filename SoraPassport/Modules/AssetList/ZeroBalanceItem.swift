/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraSwiftUI

final class ZeroBalanceItem: NSObject {

    var isShown: Bool
    var buttonHandler: (() -> Void)?

    init(isShown: Bool) {
        self.isShown = isShown
    }
}

extension ZeroBalanceItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ZeroBalanceCell.self }

    var backgroundColor: SoramitsuColor { .bgPage }

    var clipsToBounds: Bool { false }
}
