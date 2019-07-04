/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol TutorialViewModelProtocol: class {
    var title: String { get }
    var details: String { get }
    var image: UIImage { get }
}

final class TutorialViewModel: TutorialViewModelProtocol {
    var title: String
    var details: String
    var imageName: String

    var image: UIImage {
        return UIImage(named: imageName)!
    }

    init(title: String, details: String, imageName: String) {
        self.title = title
        self.details = details
        self.imageName = imageName
    }
}
