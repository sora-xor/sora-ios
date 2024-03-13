//
//  TransferCompleteEvent.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

struct TransferCompleteEvent {
    let payload: ConfirmationPayload
}

extension TransferCompleteEvent: WalletEventProtocol {
    func accept(visitor: WalletEventVisitorProtocol) {
        visitor.processTransferComplete(event: self)
    }
}
