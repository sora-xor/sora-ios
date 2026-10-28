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

protocol KeystoreImportObserver: AnyObject {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?)
}

protocol KeystoreImportServiceProtocol: URLHandlingServiceProtocol {
    var definition: KeystoreDefinition? { get }

    func add(observer: KeystoreImportObserver)

    func remove(observer: KeystoreImportObserver)

    func clear()
}

final class KeystoreImportService {
    private struct ObserverWrapper {
        weak var observer: KeystoreImportObserver?
    }

    private var observers: [ObserverWrapper] = []

    private(set) var definition: KeystoreDefinition?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension KeystoreImportService: KeystoreImportServiceProtocol {
    func handle(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)

            let oldDefinition = definition
            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: data)

            self.definition = definition

            observers.forEach { wrapper in
                wrapper.observer?.didUpdateDefinition(from: oldDefinition)
            }

            logger.debug("Keystore definition imported")

            return true
        } catch {
            logger.warning("Keystore definition import failed")
            return false
        }
    }

    func add(observer: KeystoreImportObserver) {
        observers = observers.filter { $0.observer !== nil}

        if observers.contains(where: { $0.observer === observer }) {
            return
        }

        let wrapper = ObserverWrapper(observer: observer)
        observers.append(wrapper)
    }

    func remove(observer: KeystoreImportObserver) {
        observers = observers.filter { $0.observer !== nil && observer !== observer}
    }

    func clear() {
        definition = nil
    }
}
