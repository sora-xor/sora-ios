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

final class EventCenter {
    static let shared = EventCenter()

    struct ObserverWrapper {
        weak var observer: EventVisitorProtocol?
        var dispatchQueue: DispatchQueue?
    }

    private let syncQueue: DispatchQueue

    private var wrappers: [ObserverWrapper] = []

    init(syncQueue: DispatchQueue? = nil) {
        self.syncQueue = syncQueue ?? DispatchQueue(label: "co.jp.soramitsu.sora.event.center")
    }
}

extension EventCenter: EventCenterProtocol {
    func notify(with event: EventProtocol) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil }

            for wrapper in self.wrappers {
                guard let observer = wrapper.observer else {
                    continue
                }

                if let queue = wrapper.dispatchQueue {
                    queue.async {
                        event.accept(visitor: observer)
                    }
                } else {
                    event.accept(visitor: observer)
                }
            }
        }
    }

    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil }

            if !self.wrappers.contains(where: { $0.observer === observer }) {
                self.wrappers.append(ObserverWrapper(observer: observer, dispatchQueue: queue))
            }
        }
    }

    func remove(observer: EventVisitorProtocol) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil && $0.observer !== observer }
        }
    }
}
