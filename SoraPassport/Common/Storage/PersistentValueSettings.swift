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

enum PersistentValueSettingsError: Error {
    case missingValue
}

class PersistentValueSettings<T> {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private let mutex = NSLock()

    var internalValue: T?

    var value: T? {
        mutex.lock()

        defer {
            mutex.unlock()
        }
        return internalValue
    }

    var hasValue: Bool { value != nil }

    func performSetup(completionClosure _: @escaping (Result<T?, Error>) -> Void) {
        fatalError("Function must be implemented in subclass")
    }

    func performSave(value _: T, completionClosure _: @escaping (Result<T, Error>) -> Void) {
        fatalError("Function must be implemented in subclass")
    }

    func setup(
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<T?, Error>) -> Void)?
    ) {
        mutex.lock()

        performSetup { result in
            if case let .success(newValue) = result {
                self.internalValue = newValue
            }

            self.mutex.unlock()

            if let closure = completionClosure {
                dispatchInQueueWhenPossible(queue) {
                    closure(result)
                }
            }
        }
    }

    func setup() {
        setup(runningCompletionIn: nil, completionClosure: nil)
    }

    func save(
        value: T,
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<T, Error>) -> Void)?
    ) {
        mutex.lock()

        performSave(value: value) { result in
            if case let .success(newValue) = result {
                self.internalValue = newValue
            }

            self.mutex.unlock()

            if let closure = completionClosure {
                dispatchInQueueWhenPossible(queue) {
                    closure(result)
                }
            }
        }
    }

    func save(value: T) {
        save(value: value, runningCompletionIn: nil, completionClosure: nil)
    }
}
