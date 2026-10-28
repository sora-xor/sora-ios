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

protocol SchedulerProtocol: AnyObject {
    func notifyAfter(_ seconds: TimeInterval)
    func cancel()
}

protocol SchedulerDelegate: AnyObject {
    func didTrigger(scheduler: SchedulerProtocol)
}

final class Scheduler: NSObject, SchedulerProtocol {
    weak var delegate: SchedulerDelegate?

    let callbackQueue: DispatchQueue?

    private var lock: NSLock = NSLock()
    private var timer: DispatchSourceTimer?

    init(with delegate: SchedulerDelegate, callbackQueue: DispatchQueue? = nil) {
        self.delegate = delegate
        self.callbackQueue = callbackQueue

        super.init()
    }

    deinit {
        cancel()
    }

    func notifyAfter(_ seconds: TimeInterval) {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearTimer()

        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now() + .milliseconds(Int(1000.0 * seconds)),
                        repeating: DispatchTimeInterval.never)
        timer?.setEventHandler { [weak self] in
            self?.handleTrigger()
        }

        timer?.resume()
    }

    func cancel() {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearTimer()
    }

    private func clearTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    @objc private func handleTrigger() {
        lock.lock()

        defer {
            lock.unlock()
        }

        timer = nil

        if let callbackQueue = callbackQueue {
            callbackQueue.async {
                self.delegate?.didTrigger(scheduler: self)
            }
        } else {
            delegate?.didTrigger(scheduler: self)
        }
    }
}
