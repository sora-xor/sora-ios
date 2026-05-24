import Combine
import Foundation

public protocol PoolsService {
    var pairsPublisher: Published<[LiquidityPair]>.Publisher { get }
    func subscribeAllPairs() async throws
    func getAllPairs() async throws -> [LiquidityPair]

    var accountPoolsPublisher: Published<[AccountPool]>.Publisher { get }
    func subscribeAccountPools(accountId: Data) async throws -> [UInt16]
    func getAccountPools(accountId: Data) async throws -> [AccountPool]

    var poolDetailsPublisher: Published<AccountPool?>.Publisher { get }

    func subscribeAccountPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) throws -> UInt16

    func getAccountPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) async throws -> AccountPool?

    func unsubscribe(id: UInt16)
}
