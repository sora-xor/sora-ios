//
//  WalletEventCenter.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

final class WalletEventCenter {
    struct ObserverWrapper {
        weak var observer: WalletEventVisitorProtocol?
        var dispatchQueue: DispatchQueue?
    }

    private let syncQueue: DispatchQueue

    private var wrappers: [ObserverWrapper] = []

    init(syncQueue: DispatchQueue? = nil) {
        self.syncQueue = syncQueue ?? DispatchQueue(label: "co.jp.soramitsu.capital.event.center")
    }
}

extension WalletEventCenter: WalletEventCenterProtocol {
    func notify(with event: WalletEventProtocol) {
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

    func add(observer: WalletEventVisitorProtocol, dispatchIn queue: DispatchQueue?) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil }

            if !self.wrappers.contains(where: { $0.observer === observer }) {
                self.wrappers.append(ObserverWrapper(observer: observer, dispatchQueue: queue))
            }
        }
    }

    func remove(observer: WalletEventVisitorProtocol) {
        syncQueue.async {
            self.wrappers = self.wrappers.filter { $0.observer != nil && $0.observer !== observer }
        }
    }
}
