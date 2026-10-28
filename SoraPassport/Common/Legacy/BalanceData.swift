//
//  BalanceData.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public struct BalanceData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case balance
        case context
    }

    public let identifier: String
    public let balance: AmountDecimal
    public let context: [String: String]?

    public init(identifier: String, balance: AmountDecimal, context: [String: String]? = nil) {
        self.identifier = identifier
        self.balance = balance
        self.context = context
    }
}
