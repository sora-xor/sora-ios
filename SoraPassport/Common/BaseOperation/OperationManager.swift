/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum OperationMode {
    case normal
}

protocol OperationManagerProtocol {
    func enqueue(operations: [Operation], in mode: OperationMode)
}

final class OperationManager {
    static let shared = OperationManager()

    private lazy var normalQueue = OperationQueue()

    private init() {}
}

extension OperationManager: OperationManagerProtocol {
    func enqueue(operations: [Operation], in mode: OperationMode) {
        switch mode {
        case .normal:
            normalQueue.addOperations(operations, waitUntilFinished: false)
        }
    }
}
