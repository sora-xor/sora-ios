/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
