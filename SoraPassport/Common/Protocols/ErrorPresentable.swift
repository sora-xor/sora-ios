/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ErrorPresentable: class {
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
}
