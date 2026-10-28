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
import SSFUtils
import RobinHood

protocol CommonTypesSyncServiceProtocol {
    func syncUp()
}

class CommonTypesSyncService {
    let url: URL?
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let dataHasher: StorageHasher
    let usesReviewedSoraBundle: Bool

    private(set) var isSyncing: Bool = false
    private(set) var retryAttempt: Int = 0

    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = {
        let scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
        return scheduler
    }()

    init(
        url: URL?,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        dataHasher: StorageHasher = .twox256,
        usesReviewedSoraBundle: Bool = false
    ) {
        self.url = url
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
        self.usesReviewedSoraBundle = usesReviewedSoraBundle
    }

    private func performSyncUpIfNeeded(with dataHasher: StorageHasher) {
        guard !isSyncing else {
            return
        }

        isSyncing = true

        let fetchOperation: BaseOperation<Data>
        if usesReviewedSoraBundle {
            fetchOperation = ClosureOperation {
                try ReviewedSoraRuntimeSnapshotAdmission
                    .loadReviewedCommonTypes()
            }
        } else {
            guard let url = url else {
                assertionFailure()
                isSyncing = false
                return
            }
            fetchOperation = dataOperationFactory.fetchData(from: url)
        }
        let saveOperation = filesOperationFactory.saveCommonTypesOperation {
            let data = try fetchOperation.extractNoCancellableResultData()
            if self.usesReviewedSoraBundle {
                try ReviewedSoraRuntimeSnapshotAdmission
                    .validateReviewedCommonTypes(data)
            }
            return data
        }

        saveOperation.addDependency(operations: [fetchOperation])

        saveOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try saveOperation.targetOperation.extractNoCancellableResultData()
                    let data = try fetchOperation.extractNoCancellableResultData()
                    if self?.usesReviewedSoraBundle == true {
                        try ReviewedSoraRuntimeSnapshotAdmission
                            .validateReviewedCommonTypes(data)
                    }

                    let remoteHash = try dataHasher.hash(data: data)

                    self?.handleCompletion(with: remoteHash)
                } catch {
                    self?.handleFailure(with: error)
                }
            }
        }

        operationQueue.addOperations(
            [fetchOperation] + saveOperation.allOperations,
            waitUntilFinished: false
        )
    }

    private func handleCompletion(with remoteHash: Data) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt = 0

        let event = RuntimeCommonTypesSyncCompleted(fileHash: remoteHash.toHex())
        eventCenter.notify(with: event)
    }

    private func handleFailure(with _: Error) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt += 1

        if let delay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(delay)
        }
    }
}

extension CommonTypesSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded(with: dataHasher)
    }
}

extension CommonTypesSyncService: CommonTypesSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded(with: dataHasher)
    }
}
