/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum NavigationBarSeparatorStyle {
    case dark
    case light
    case empty
}

protocol DesignableNavigationBarProtocol {
    var separatorStyle: NavigationBarSeparatorStyle { get }
}
