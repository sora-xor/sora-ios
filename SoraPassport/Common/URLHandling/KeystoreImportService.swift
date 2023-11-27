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

            let address = definition.address ?? "no address"
            logger.debug("Imported keystore for address: \(address)")

            return true
        } catch {
            logger.warning("Error while parsing keystore from url: \(error)")
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
