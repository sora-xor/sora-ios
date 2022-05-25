/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class SelectableSubtitleListViewModel: SelectableViewModelProtocol {
    var title: String
    var subtitle: String

    init(title: String, subtitle: String, isSelected: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
    }
}
