//
//  FiatTextBuilder.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 9/26/23.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import sorawallet
import CommonWallet

struct FiatTextBuilder {
    func build(fiatData: [FiatData], amount: Decimal, assetId: String) -> String {
        var fiatText = ""
        if let priceUsd = fiatData.first(where: { $0.id == assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = amount * priceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        return fiatText
    }
}
