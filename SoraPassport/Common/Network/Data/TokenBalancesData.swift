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

struct TokenBalancesData {
    let soranet: Decimal
    let ethereum: Decimal
}

extension TokenBalancesData {
    init(balanceContext: [String: String]) {
        if let balanceString = balanceContext[WalletOperationContextKey.Balance.soranet],
           let balance = Decimal(string: balanceString) {
            soranet = balance
        } else {
            soranet = 0
        }

        if let balanceString = balanceContext[WalletOperationContextKey.Balance.erc20],
           let balance = Decimal(string: balanceString) {
            ethereum = balance
        } else {
            ethereum = 0
        }
    }

    init(sendingContext: [String: String]) {
        var soranet: Decimal = 0
        var ethereum: Decimal = 0

        if let balanceString = sendingContext[WalletOperationContextKey.SoranetTransfer.balance],
           let balance = Decimal(string: balanceString) {
            soranet += balance
        }

        if let balanceString = sendingContext[WalletOperationContextKey.SoranetWithdraw.balance],
           let balance = Decimal(string: balanceString) {
            soranet += balance
        }

        if let balanceString = sendingContext[WalletOperationContextKey.ERC20Transfer.balance],
           let balance = Decimal(string: balanceString) {
            ethereum += balance
        }

        if let balanceString = sendingContext[WalletOperationContextKey.ERC20Withdraw.balance],
           let balance = Decimal(string: balanceString) {
            ethereum += balance
        }

        self.soranet = soranet
        self.ethereum = ethereum
    }
}
