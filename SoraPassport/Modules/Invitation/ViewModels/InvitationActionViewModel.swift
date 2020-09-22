/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

enum InvitationActionStyle {
    case normal
    case critical
}

struct InvitationActionViewModel {
    let title: String
    let icon: UIImage?
    let accessoryText: String?
    let style: InvitationActionStyle
}
