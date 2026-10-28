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

import RobinHood

final class SendAssetItem: NSObject {
    
    let imageViewModel: WalletImageViewModelProtocol?
    let symbol: String
    let amount: String
    let balance: String
    let fiat: String
    
    init(imageViewModel: WalletImageViewModelProtocol?,
         symbol: String,
         amount: String,
         balance: String,
         fiat: String) {
        self.imageViewModel = imageViewModel
        self.symbol = symbol
        self.amount = amount
        self.balance = balance
        self.fiat = fiat
    }
}

extension SendAssetItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { SendAssetCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
