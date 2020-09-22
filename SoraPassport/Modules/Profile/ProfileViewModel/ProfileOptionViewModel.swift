/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol ProfileOptionViewModelProtocol: class {
    var icon: UIImage { get }
    var title: String { get }
    var accessoryTitle: String? { get }
    var accessoryIcon: UIImage? { get }
}

final class ProfileOptionViewModel: ProfileOptionViewModelProtocol {
    var title: String
    var icon: UIImage
    var accessoryTitle: String?
    var accessoryIcon: UIImage?

    init(title: String, icon: UIImage) {
        self.title = title
        self.icon = icon
    }
}
