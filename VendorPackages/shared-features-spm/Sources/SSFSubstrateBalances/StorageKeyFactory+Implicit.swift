import Foundation
import SSFUtils

extension StorageKeyFactoryProtocol {
    func tokensAccountsKeyForId(_ identifier: Data, assetId: Data) throws -> Data {
        let codingPath = StorageCodingPath.tokensAccounts
        return try createStorageKey(
            moduleName: codingPath.moduleName,
            storageName: codingPath.itemName,
            key1: identifier,
            hasher1: .blake128Concat,
            key2: assetId,
            hasher2: .twox64Concat
        )
    }

    func systemAccountKeyForId(_ identifier: Data) throws -> Data {
        let codingPath = StorageCodingPath.systemAccount
        return try createStorageKey(
            moduleName: codingPath.moduleName,
            storageName: codingPath.itemName,
            key: identifier,
            hasher: .blake128Concat
        )
    }
}
