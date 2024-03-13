//
//  AssetTransactionFee.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public struct AssetTransactionFee: Codable, Equatable {
    public let identifier: String
    public let assetId: String
    public let amount: AmountDecimal
    public let context: [String: String]?

    public init(identifier: String, assetId: String, amount: AmountDecimal, context: [String: String]?) {
        self.identifier = identifier
        self.assetId = assetId
        self.amount = amount
        self.context = context
    }
}
