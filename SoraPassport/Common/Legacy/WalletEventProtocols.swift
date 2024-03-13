//
//  WalletEventProtocols.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

protocol WalletEventProtocol {
    func accept(visitor: WalletEventVisitorProtocol)
}

protocol WalletEventCenterProtocol {
    func notify(with event: WalletEventProtocol)
    func add(observer: WalletEventVisitorProtocol, dispatchIn queue: DispatchQueue?)
    func remove(observer: WalletEventVisitorProtocol)
}

extension WalletEventCenterProtocol {
    func add(observer: WalletEventVisitorProtocol) {
        add(observer: observer, dispatchIn: nil)
    }
}
