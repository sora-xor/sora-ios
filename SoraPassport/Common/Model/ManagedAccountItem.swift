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
import IrohaCrypto

struct AccountSettings: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case visibleAssetIds
        case orderedAssetIds
    }

    var visibleAssetIds: [String]?
    var orderedAssetIds: [String]?
}

struct ManagedAccountItem: Equatable {
    let address: String
    let cryptoType: CryptoType
    let networkType: SNAddressType
    let username: String
    let publicKeyData: Data
    let order: Int16
    let settings: AccountSettings
    let isSelected: Bool
}

extension ManagedAccountItem {
    func replacingOrder(_ newOrder: Int16) -> ManagedAccountItem {
        ManagedAccountItem(address: address,
                           cryptoType: cryptoType,
                           networkType: networkType,
                           username: username,
                           publicKeyData: publicKeyData,
                           order: newOrder,
                           settings: settings,
                           isSelected: isSelected)
    }

    func replacingUsername(_ newUsername: String) -> ManagedAccountItem {
        ManagedAccountItem(address: address,
                           cryptoType: cryptoType,
                           networkType: networkType,
                           username: newUsername,
                           publicKeyData: publicKeyData,
                           order: order,
                           settings: settings,
                           isSelected: isSelected)
    }

    func replacingSettings(_ newSettings: AccountSettings) -> ManagedAccountItem {
        ManagedAccountItem(address: address,
                           cryptoType: cryptoType,
                           networkType: networkType,
                           username: username,
                           publicKeyData: publicKeyData,
                           order: order,
                           settings: newSettings,
                           isSelected: isSelected)
    }
}
