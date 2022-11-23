/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct SelectableViewModel<T> {
    let underlyingViewModel: T
    let selectable: Bool
}
