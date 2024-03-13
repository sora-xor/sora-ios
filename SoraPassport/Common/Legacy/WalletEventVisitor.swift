//
//  WalletEventVisitor.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

protocol WalletEventVisitorProtocol: AnyObject {
    func processTransferComplete(event: TransferCompleteEvent)
    func processWithdrawComplete(event: WithdrawCompleteEvent)
    func processAccountUpdate(event: AccountUpdateEvent)
}

extension WalletEventVisitorProtocol {
    func processTransferComplete(event: TransferCompleteEvent) {}
    func processWithdrawComplete(event: WithdrawCompleteEvent) {}
    func processAccountUpdate(event: AccountUpdateEvent) {}
}
