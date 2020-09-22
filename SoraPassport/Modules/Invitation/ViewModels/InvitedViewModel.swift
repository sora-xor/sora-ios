/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol InvitedViewModelProtocol: class {
    var fullName: String { get }
}

class InvitedViewModel: InvitedViewModelProtocol {
    var fullName: String

    init(fullName: String) {
        self.fullName = fullName
    }
}
