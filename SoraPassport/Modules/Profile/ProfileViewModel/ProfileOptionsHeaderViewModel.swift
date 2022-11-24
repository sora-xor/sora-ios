/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ProfileOptionsHeaderViewModelProtocol {

    var title: String { get }
    
    var options: [ProfileOptionViewModelProtocol] { get }
}

struct ProfileOptionsHeaderViewModel: ProfileOptionsHeaderViewModelProtocol {

    var title: String

    var options: [ProfileOptionViewModelProtocol]

    init(by title: String, options: [ProfileOptionViewModelProtocol]) {
        self.title = title
        self.options = options
    }
}
