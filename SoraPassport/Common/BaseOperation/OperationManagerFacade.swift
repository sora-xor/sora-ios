/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class OperationManagerFacade {
    static let sharedManager: OperationManagerProtocol = OperationManager()
    static let transfer: OperationManagerProtocol = OperationManager()
}
