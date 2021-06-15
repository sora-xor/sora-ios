/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

protocol BaseServiceProtocol {
    var operationManager: OperationManagerProtocol { get set }
    var executionMode: OperationMode { get set }

    func execute(operations: [Operation])
}

class BaseService: BaseServiceProtocol {
    var operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager
    var executionMode: OperationMode = .transient

    func execute(operations: [Operation]) {
        operationManager.enqueue(operations: operations, in: executionMode)
    }
}
