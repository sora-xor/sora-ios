//
//  WithdrawInfo.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public struct WithdrawInfo {
    public var destinationAccountId: String
    public var assetId: String
    public var amount: AmountDecimal
    public var details: String
    public var fees: [Fee]

    public init(destinationAccountId: String,
                assetId: String,
                amount: AmountDecimal,
                details: String,
                fees: [Fee]) {
        self.destinationAccountId = destinationAccountId
        self.assetId = assetId
        self.amount = amount
        self.details = details
        self.fees = fees
    }
}
