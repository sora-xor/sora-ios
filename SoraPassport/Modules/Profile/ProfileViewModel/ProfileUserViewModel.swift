/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol ProfileUserViewModelProtocol: class {
    var name: String { get }
    var details: String { get }
}

final class ProfileUserViewModel: ProfileUserViewModelProtocol {
    var name: String
    var details: String

    init(name: String, details: String) {
        self.name = name
        self.details = details
    }
}
