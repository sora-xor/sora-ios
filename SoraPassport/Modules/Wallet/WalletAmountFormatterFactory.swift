/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

//
//  WalletAmountFormatterFactory.swift
//  SoraPassport
//
//  Created by Ruslan Rezin on 26.02.2020.
//  Copyright © 2020 Ruslan Rezin. All rights reserved.
//

import Foundation
import CommonWallet
import SoraFoundation

struct WalletAmountFormatterFactory: NumberFormatterFactoryProtocol {
    let ethAssetId: String

    func createInputFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        return createFormatter(for: asset)
    }

    func createDisplayFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        return createFormatter(for: asset)
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenAmountFormatter> {
        let numberFormatter = createNumberFormatter(for: asset)

        if asset?.identifier == ethAssetId {
            return TokenAmountFormatter(numberFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: " ",
                                        position: .suffix).localizableResource()
        } else {
            return TokenAmountFormatter(numberFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: "",
                                        position: .prefix).localizableResource()
        }
    }

    private func createFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        createNumberFormatter(for: asset).localizableResource()
    }

    private func createNumberFormatter(for asset: WalletAsset?) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter
    }
}
