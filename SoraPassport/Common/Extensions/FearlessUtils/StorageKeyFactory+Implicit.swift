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

import FearlessUtils
import Foundation

enum PalleteName: String {
//    case System
//    case PoolXYK
//    case MulticollateralBondingCurvePool
//    case Referrals
//    case Staking
//    case Tokens
    case Assets
}

extension StorageKeyFactoryProtocol {
    func newBlock() throws -> Data {
        try createStorageKey(moduleName: "System",
                             storageName: "ParentHash")
    }
    
    func updatedDualRefCount() throws -> Data {
        try createStorageKey(moduleName: "System",
                             storageName: "UpgradedToDualRefCount")
    }

    func assetsInfoKeysPaged() throws -> Data {
        try createStorageKey(moduleName: PalleteName.Assets.rawValue,
                             storageName: "AssetInfos")
    }

    func accountInfoKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "System",
                             storageName: "Account",
                             key: identifier,
                             hasher: .blake128Concat)
    }

    func accountPoolsKeyForId(_ identifier: Data, baseAssetId: Data) throws -> Data {
        try createStorageKey(moduleName: "PoolXYK",
                             storageName: "AccountPools",
                             key1: identifier,
                             hasher1: .identity,
                             key2: baseAssetId,
                             hasher2: .blake128Concat)
    }

    func accountPoolTotalIssuancesKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "PoolXYK", storageName: "TotalIssuances") + identifier
    }

    func poolPropertiesKey(baseAssetId: Data, targetAssetId: Data) throws -> Data {
        try createStorageKey(
            moduleName: "PoolXYK",
            storageName: "Properties",
            key1: baseAssetId,
            hasher1: .blake128Concat,
            key2: targetAssetId,
            hasher2: .blake128Concat
        )
    }

    func poolReservesKey(baseAssetId: Data, targetAssetId: Data) throws -> Data {
        try createStorageKey(
            moduleName: "PoolXYK",
            storageName: "Reserves",
            key1: baseAssetId,
            hasher1: .blake128Concat,
            key2: targetAssetId,
            hasher2: .blake128Concat
        )
    }

    func poolProvidersKey(reservesAccountId: Data, accountId: Data) throws -> Data {
        try createStorageKey(moduleName: "PoolXYK", storageName: "PoolProviders") + reservesAccountId + accountId
    }

    func bondedKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             storageName: "Bonded",
                             key: identifier,
                             hasher: .twox64Concat)
    }

    func stakingInfoForControllerId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             storageName: "Ledger",
                             key: identifier,
                             hasher: .blake128Concat)
    }

    func activeEra() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             storageName: "ActiveEra")
    }

    func currentEra() throws -> Data {
        try createStorageKey(moduleName: "Staking",
                             storageName: "CurrentEra")
    }

    func totalIssuance() throws -> Data {
        try createStorageKey(moduleName: "Balances",
                             storageName: "TotalIssuance")
    }

    func key(from codingPath: StorageCodingPath) throws -> Data {
        try createStorageKey(moduleName: codingPath.moduleName, storageName: codingPath.itemName)
    }
    
    func xykPoolKey(asset1: Data, asset2: Data) throws -> Data {
        try createStorageKey(moduleName: "PoolXYK",
                             storageName: "Reserves",
                             key1: asset1,
                             hasher1: .blake128Concat,
                             key2: asset2,
                             hasher2: .blake128Concat)
    }

    func tbcPoolKey(asset: Data) throws -> Data {
        try createStorageKey(moduleName: "MulticollateralBondingCurvePool",
                             storageName: "CollateralReserves",
                             key: asset,
                             hasher: .twox64Concat)
    }

    func referrerBalancesKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Referrals",
                             storageName: "ReferrerBalances",
                             key: identifier,
                             hasher: .blake128Concat)
    }

    func referrersKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Referrals",
                             storageName: "Referrers",
                             key: identifier,
                             hasher: .blake128Concat)
    }

    func accountsKey(account: Data, asset: Data) throws -> Data {
        try createStorageKey(moduleName: "Tokens",
                             storageName: "Accounts",
                             key1: account,
                             hasher1: .blake128Concat,
                             key2: asset,
                             hasher2: .twox64Concat)
    }

    func accountsKey(account: Data) throws -> Data {
        try createStorageKey(moduleName: "Tokens",
                             storageName: "Accounts",
                             key: account,
                             hasher: .blake128Concat)
    }

    func referralsKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "Referrals",
                             storageName: "Referrals",
                             key: identifier,
                             hasher: .blake128Concat)
    }
    
    func xstPoolBaseFee() throws -> Data {
        try createStorageKey(moduleName: "XstPool",
                             storageName: "BaseFee")
    }
    
    func demeterFarmingUserInfo(identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "DemeterFarmingPlatform",
                             storageName: "UserInfos",
                             key: identifier,
                             hasher: .blake128Concat)
    }
 }
