import FearlessUtils
import Foundation

extension StorageKeyFactoryProtocol {
    func updatedDualRefCount() throws -> Data {
        try createStorageKey(moduleName: "System",
                             storageName: "UpgradedToDualRefCount")
    }

    func accountInfoKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "System",
                             storageName: "Account",
                             key: identifier,
                             hasher: .blake128Concat)
    }

    func accountPoolsKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(moduleName: "PoolXYK", storageName: "AccountPools") + identifier
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
 }
