/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension AccountItem: Identifiable {
    var identifier: String { address }
}

extension ConnectionItem: Identifiable {
    var identifier: String { url.absoluteString }
}

extension ManagedAccountItem: Identifiable {
    var identifier: String { address }
}

extension ManagedConnectionItem: Identifiable {
    var identifier: String { url.absoluteString }

}
