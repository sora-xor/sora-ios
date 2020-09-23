/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension Result where Success == Void {
    static var success: Result { .success(()) }
}
