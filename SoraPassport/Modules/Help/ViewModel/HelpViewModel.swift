/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

struct HelpViewModelContent {
    var title: String
    var details: String
}

struct HelpViewModelLayout {
    var itemSize: CGSize
    var titleRect: CGRect
    var detailsRect: CGRect
}

protocol HelpViewModelProtocol: class {
    var content: HelpViewModelContent { get }
    var layout: HelpViewModelLayout { get }
}

final class HelpViewModel: HelpViewModelProtocol {
    var content: HelpViewModelContent
    var layout: HelpViewModelLayout

    init(content: HelpViewModelContent, layout: HelpViewModelLayout) {
        self.content = content
        self.layout = layout
    }
}
