// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import FearlessUtils
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
        dataHasher: StorageHasher = .twox256
    ) {
        self.url = url
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
    }

    private func performSyncUpIfNeeded(with dataHasher: StorageHasher) {
        guard !isSyncing else {
            return
        }

        guard let url = url else {
            assertionFailure()
            return
        }

        isSyncing = true

        let fetchOperation = dataOperationFactory.fetchData(from: url)
        let saveOperation = filesOperationFactory.saveCommonTypesOperation {
            try fetchOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(operations: [fetchOperation])

        saveOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try saveOperation.targetOperation.extractNoCancellableResultData()
                    let data = try fetchOperation.extractNoCancellableResultData()

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
