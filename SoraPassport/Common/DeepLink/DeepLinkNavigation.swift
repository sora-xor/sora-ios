/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol DeepLinkNavigatorProtocol {
    func navigate(to invitation: InvitationDeepLink) -> Bool
}

protocol DeepLinkProtocol {
    func accept(navigator: DeepLinkNavigatorProtocol) -> Bool
}
