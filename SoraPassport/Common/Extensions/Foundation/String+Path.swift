/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension String {
    func appendingPathCompletionRegex() -> String {
        return self + "(/\\S*)?"
    }
}
