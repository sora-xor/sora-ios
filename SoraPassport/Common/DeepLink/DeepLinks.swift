/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct InvitationDeepLink: DeepLinkProtocol {
    let code: String

    func accept(navigator: DeepLinkNavigatorProtocol) -> Bool {
        return navigator.navigate(to: self)
    }
}
