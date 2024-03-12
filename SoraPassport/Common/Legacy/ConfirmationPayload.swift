//
//  ConfirmationPayload.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public struct ConfirmationPayload {
    public let transferInfo: TransferInfo
    public let receiverName: String

    public init(transferInfo: TransferInfo, receiverName: String) {
        self.transferInfo = transferInfo
        self.receiverName = receiverName
    }
}
