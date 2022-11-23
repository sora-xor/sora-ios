/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CoreGraphics

protocol TitleDescriptionViewModelProtocol {
    var title: String { get }
    var descriptionText: String { get set }
}

struct TitleDescriptionViewModel: TitleDescriptionViewModelProtocol {
    var title: String
    var descriptionText: String

    init(title: String, descriptionText: String) {
        self.title = title
        self.descriptionText = descriptionText
    }
}

extension TitleDescriptionViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return TitleDescriptionCell.reuseIdentifier
    }
}
