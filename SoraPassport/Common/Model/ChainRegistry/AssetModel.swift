// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood

struct AssetModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String
    typealias PriceId = String

    let id: String
    let symbol: String
    let chainId: String
    let precision: UInt16
    let icon: URL?
    let priceId: PriceId?
    let price: Decimal?
    let transfersEnabled: Bool?
    let type: ChainAssetType
    let currencyId: String?
    let displayName: String?
    let existentialDeposit: String?

    var name: String {
        displayName?.uppercased() ?? symbol.uppercased()
    }

    init(
        id: String,
        symbol: String,
        chainId: String,
        precision: UInt16,
        icon: URL?,
        priceId: AssetModel.PriceId?,
        price: Decimal?,
        transfersEnabled: Bool?,
        type: ChainAssetType,
        currencyId: String?,
        displayName: String?,
        existentialDeposit: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.chainId = chainId
        self.precision = precision
        self.icon = icon
        self.priceId = priceId
        self.price = price
        self.transfersEnabled = transfersEnabled
        self.type = type
        self.currencyId = currencyId
        self.displayName = displayName
        self.existentialDeposit = existentialDeposit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        chainId = try container.decode(String.self, forKey: .chainId)
        precision = try container.decode(UInt16.self, forKey: .precision)
        icon = try? container.decode(URL?.self, forKey: .icon)
        priceId = try? container.decode(String?.self, forKey: .priceId)
        transfersEnabled = try? container.decode(Bool?.self, forKey: .transfersEnabled)
        currencyId = try? container.decode(String?.self, forKey: .currencyId)
        displayName = try? container.decode(String?.self, forKey: .displayName)
        existentialDeposit = try? container.decode(String?.self, forKey: .existentialDeposit)

        price = nil
        type = .normal
    }

    func replacingPrice(_ newPrice: Decimal?) -> AssetModel {
        AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: precision,
            icon: icon,
            priceId: priceId,
            price: newPrice,
            transfersEnabled: transfersEnabled,
            type: type,
            currencyId: currencyId,
            displayName: displayName,
            existentialDeposit: existentialDeposit
        )
    }

    static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.chainId == rhs.chainId &&
            lhs.precision == rhs.precision &&
            lhs.icon == rhs.icon &&
            lhs.priceId == rhs.priceId &&
            lhs.symbol == rhs.symbol &&
            lhs.type == rhs.type &&
            lhs.transfersEnabled == rhs.transfersEnabled &&
            lhs.currencyId == rhs.currencyId &&
            lhs.displayName == rhs.displayName
    }
}

extension AssetModel: Identifiable {
    var identifier: String { id }
}
