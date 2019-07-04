/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

struct AnnouncementItemLayout: Withable {
    var itemSize: CGSize = .zero
    var messageSize: CGSize = .zero
}

struct AnnouncementItemContent {
    var message: String
}

protocol AnnouncementItemViewModelProtocol: class {
    var content: AnnouncementItemContent { get }
    var layout: AnnouncementItemLayout { get }
}

final class AnnouncementItemViewModel: AnnouncementItemViewModelProtocol {
    var content: AnnouncementItemContent
    var layout: AnnouncementItemLayout

    init(content: AnnouncementItemContent, layout: AnnouncementItemLayout) {
        self.content = content
        self.layout = layout
    }
}
