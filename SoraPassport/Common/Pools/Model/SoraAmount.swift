//
//  SoraAmount.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 1/30/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import SSFUtils
import BigInt

public enum SoraAmountDecimalError: Error {
    case invalidStringValue
}

struct SoraAmountDecimal: Decodable, Equatable {
    public let value: BigUInt

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let stringValue = try container.decode(String.self)

        guard let value = BigUInt(stringValue) else {
            throw SoraAmountDecimalError.invalidStringValue
        }

        self.value = value
    }
}
