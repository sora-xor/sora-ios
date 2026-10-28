// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SoraUIKit


final class TransferableItem: NSObject {

    var assetInfo: AssetInfo
    var fiat: String
    var balance: Amount
    var actionHandler: ((TransferableActionType) -> Void)?
    var frozenAmount: Amount?
    var frozenFiatAmount: String?
    var balanceData: BalanceData
    var service: TransferableItemService
    /// The balance could not be read when the item was made; `balance` is
    /// a placeholder. What holds now is `service.balanceUnavailable`.
    let balanceUnavailable: Bool
    
    init(
        assetInfo: AssetInfo,
        fiat: String,
        balance: Amount,
        frozenAmount: Amount? = nil,
        frozenFiatAmount: String? = nil,
        service: TransferableItemService,
        balanceData: BalanceData,
        balanceUnavailable: Bool = false
    ) {
        self.assetInfo = assetInfo
        self.fiat = fiat
        self.balance = balance
        self.frozenAmount = frozenAmount
        self.frozenFiatAmount = frozenFiatAmount
        self.balanceData = balanceData
        self.service = service
        self.balanceUnavailable = balanceUnavailable
        if balanceUnavailable {
            self.service.setupUnavailable()
        } else {
            self.service.setup(with: balanceData)
        }
    }
}

extension TransferableItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { TransferableCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
