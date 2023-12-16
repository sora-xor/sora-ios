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

public enum CryptoType: UInt8, Codable, CaseIterable {
    case sr25519
    case ed25519
    case ecdsa
    
    var typeString: String {
        switch self {
        case .sr25519: return "SR25519"
        case .ed25519: return "ED25519"
        case .ecdsa: return "ECDSA"
        }
    }
    
    init(type: String) {
        switch type {
        case "SR25519":
            self = .sr25519
        case "ED25519":
            self = .ed25519
        case "ECDSA":
            self = .ecdsa
        default:
            self = .sr25519
        }
    }
}

struct AccountItem: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case address
        case cryptoType
        case networkType
        case username
        case publicKeyData
        case settings
        case isSelected
        case order
    }

    let address: String
    let cryptoType: CryptoType
    let networkType: SNAddressType
    let username: String
    let publicKeyData: Data
    let settings: AccountSettings
    let isSelected: Bool
    let order: Int16

    public init(from decoder: Decoder) throws {
        let containter = try decoder.container(keyedBy: CodingKeys.self)
        address = try containter.decode(String.self, forKey: .address)
        cryptoType = try containter.decode(CryptoType.self, forKey: .cryptoType)
        networkType = try containter.decodeIfPresent(SNAddressType.self, forKey: .networkType) ?? ApplicationConfig.shared.addressType
        username = try containter.decode(String.self, forKey: .username)
        publicKeyData = try containter.decode(Data.self, forKey: .publicKeyData)
        settings = try containter.decodeIfPresent(AccountSettings.self, forKey: .settings) ?? AccountSettings(visibleAssetIds: [], orderedAssetIds: [])
        isSelected = try containter.decodeIfPresent(Bool.self, forKey: .isSelected) ?? false
        order = try containter.decodeIfPresent(Int16.self, forKey: .order) ?? 0
    }

    init(address: String,
         cryptoType: CryptoType,
         networkType: SNAddressType,
         username: String,
         publicKeyData: Data,
         settings: AccountSettings,
         order: Int16,
         isSelected: Bool) {
        self.address = address
        self.cryptoType = cryptoType
        self.networkType = networkType
        self.username = username
        self.publicKeyData = publicKeyData
        self.settings = settings
        self.isSelected = isSelected
        self.order = order
    }
}

extension AccountItem {
    init(managedItem: ManagedAccountItem) {
        self = AccountItem(address: managedItem.address,
                           cryptoType: managedItem.cryptoType,
                           networkType: managedItem.networkType,
                           username: managedItem.username,
                           publicKeyData: managedItem.publicKeyData,
                           settings: managedItem.settings,
                           order: managedItem.order,
                           isSelected: managedItem.isSelected)
    }

    var addressType: SNAddressType {
        ApplicationConfig.shared.addressType
    }

    func replacingUsername(_ newUsername: String) -> AccountItem {
        AccountItem(address: address,
                    cryptoType: cryptoType,
                    networkType: networkType,
                    username: newUsername,
                    publicKeyData: publicKeyData,
                    settings: settings,
                    order: order,
                    isSelected: isSelected)
    }

    func replacingSettings(_ newSettings: AccountSettings) -> AccountItem {
        AccountItem(address: address,
                    cryptoType: cryptoType,
                    networkType: networkType,
                    username: username,
                    publicKeyData: publicKeyData,
                    settings: newSettings,
                    order: order,
                    isSelected: isSelected)
    }
}
