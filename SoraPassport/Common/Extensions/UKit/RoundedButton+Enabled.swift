/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraUI

extension RoundedButton {
    func enable() {
        isEnabled = true
        alpha = 1.0
    }

    func disable() {
        isEnabled = false
        alpha = 0.5
    }
}
