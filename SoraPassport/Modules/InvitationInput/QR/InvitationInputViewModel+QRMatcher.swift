/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension CodeInputViewModel: QRMatcherProtocol {
    func match(code: String) -> Bool {
        return didReceiveReplacement(code, for: NSRange(location: 0, length: self.code.count))
    }
}
