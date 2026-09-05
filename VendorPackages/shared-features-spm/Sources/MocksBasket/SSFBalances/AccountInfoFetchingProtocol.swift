import Foundation
import SSFModels
import SSFAssetManagment

protocol AccountInfoFetchingProtocol {
    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> (ChainAsset, AccountInfo?)

    func fetch(
        for chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> [ChainAsset: AccountInfo?]

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> [ChainAssetKey: AccountInfo?]
}
