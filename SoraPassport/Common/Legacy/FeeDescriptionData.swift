//
//  FeeDescriptionData.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

public struct FeeDescription: Codable, Equatable {
    public let identifier: String
    public let assetId: String
    public let type: String
    public let parameters: [AmountDecimal]
    public let accountId: String?
    public let minValue: AmountDecimal?
    public let maxValue: AmountDecimal?
    public let context: [String: String]?

    public init(identifier: String,
                assetId: String,
                type: String,
                parameters: [AmountDecimal],
                accountId: String? = nil,
                minValue: AmountDecimal? = nil,
                maxValue: AmountDecimal? = nil,
                context: [String: String]? = nil) {
        self.identifier = identifier
        self.assetId = assetId
        self.type = type
        self.accountId = accountId
        self.parameters = parameters
        self.minValue = minValue
        self.maxValue = maxValue
        self.context = context
    }
}

public extension FeeDescription {
    var userCanDefine: Bool {
        minValue != nil || maxValue != nil
    }
}
