// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    private var operation: BaseOperation<[PhishingItem]>
    private var logger: LoggerProtocol
    private var storage: CoreDataRepository<PhishingItem, CDPhishingItem>

    init(operation: BaseOperation<[PhishingItem]>,
         logger: LoggerProtocol,
         storage: CoreDataRepository<PhishingItem, CDPhishingItem>) {
        self.operation = operation
        self.logger = logger
        self.storage = storage
    }

    enum State {
        case throttled
        case active
        case inactive
    }

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false

        setupConnection()
    }

    func throttle() {
        guard !isThrottled else {
            return
        }

        isThrottled = true

        clearConnection()
    }

    private func clearConnection() {
        operation.cancel()
    }

    private func setupConnection() {
        operation.completionBlock = { [self] in
            do {
                if let phishingItems = try operation.extractResultData() {
                    let deleteOperation = storage.deleteAllOperation()
                    OperationManagerFacade.sharedManager.enqueue(operations: [deleteOperation], in: .sync)

                    for phishingItem in phishingItems {
                        let saveOperation = storage.saveOperation({ [phishingItem] }, { [] })
                        OperationManagerFacade.sharedManager.enqueue(operations: [saveOperation], in: .sync)
                    }
                }
            } catch {
                self.logger.error("Request unsuccessful")
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .sync)
    }
}
