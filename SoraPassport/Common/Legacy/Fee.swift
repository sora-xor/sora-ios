//
//  Fee.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public struct Fee: Codable, Equatable {
    public var value: AmountDecimal
    public var feeDescription: FeeDescription

    public init(value: AmountDecimal, feeDescription: FeeDescription) {
        self.value = value
        self.feeDescription = feeDescription
    }
}
