//
//  WalletWithdrawOption.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

public struct WalletWithdrawOption {
    public let identifier: String
    public let symbol: String
    public let shortTitle: String
    public let longTitle: String
    public let details: String
    public let icon: UIImage?

    public init(identifier: String,
                symbol: String,
                shortTitle: String,
                longTitle: String,
                details: String,
                icon: UIImage?) {
        self.identifier = identifier
        self.symbol = symbol
        self.shortTitle = shortTitle
        self.longTitle = longTitle
        self.details = details
        self.icon = icon
    }
}
