import Foundation
import SSFUtils

enum PolkaswapServiceError: Error {
    case unexpectedError
}

protocol PoolsService {
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

    func unsubscribeAll()
}

final class PolkaswapService {
    
    @Published var liquidityPairs: [LiquidityPair] = []
    var pairsPublisher: Published<[LiquidityPair]>.Publisher { $liquidityPairs }
    
    @Published var accountPools: [AccountPool] = []
    var accountPoolsPublisher: Published<[AccountPool]>.Publisher { $accountPools }
    
    @Published var poolDetails: AccountPool?
    var poolDetailsPublisher: Published<AccountPool?>.Publisher { $poolDetails }
    
    private let remoteService: RemotePolkaswapPoolsService
    private let localPairService: LocalLiquidityPairService
    private let localAccountPoolService: LocalAccountPoolsService
    private let subscriptionService: PoolSubscriptionService
    
    init(
        remoteService: RemotePolkaswapPoolsService,
        localPairService: LocalLiquidityPairService,
        localAccountPoolService: LocalAccountPoolsService,
        subscriptionService: PoolSubscriptionService
    ) {
        self.remoteService = remoteService
        self.localPairService = localPairService
        self.localAccountPoolService = localAccountPoolService
        self.subscriptionService = subscriptionService
    }
}

extension PolkaswapService: PoolsService {
    func subscribeAccountPools(accountId: Data) async throws -> [UInt16] {
        let baseAssetIds = try await remoteService.getBaseAssetIds()
        
        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
            Task { [weak self] in
                guard let self else { return }
                self.accountPools = try await self.getAccountPools(accountId: accountId)
            }
        }
        
        return try baseAssetIds.compactMap { baseAssetId in
            try subscriptionService.createAccountPoolsSubscription(
                accountId: accountId,
                baseAssetId: baseAssetId,
                updateClosure: updateClosure
            )
        }
    }
    
    func getAccountPools(accountId: Data) async throws -> [AccountPool] {
        do {
            var accountPools = try await remoteService.getAccountPools(accountId: accountId)
            
            accountPools = try await accountPools.asyncMap { [weak self] pool in
                let apy = try await self?.remoteService.getAPY(reservesId: pool.reservesId)
                return pool.update(apy: apy)
            }

            try await localAccountPoolService.sync(remoteAccounts: accountPools)

            return accountPools
        } catch {
            return try await localAccountPoolService.get()
        }
    }

    func subscribeAccountPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) throws -> UInt16 {
        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
            Task { [weak self] in
                guard let self else { return }

                self.poolDetails = try await self.getAccountPoolDetails(
                    accountId: accountId,
                    baseAsset: baseAsset,
                    targetAsset: targetAsset
                )
            }
        }

        return try subscriptionService.createPoolReservesSubscription(
            baseAssetId: baseAsset.id,
            targetAssetId: targetAsset.id,
            updateClosure: updateClosure
        )
    }
    
    func getAccountPoolDetails(
        accountId: Data,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo
    ) async throws -> AccountPool? {
        do {
            let poolDetails = try await remoteService.getPoolDetails(
                accountId: accountId,
                baseAsset: baseAsset,
                targetAsset: targetAsset
            )

            try await localAccountPoolService.sync(remoteAccounts: accountPools)

            return poolDetails
        } catch {
            let pools = try? await localAccountPoolService.get()
            return pools?.first { $0.baseAssetId == baseAsset.id && $0.targetAssetId == targetAsset.id }
        }
    }
    
    func subscribeAllPairs() async throws {
        do {
            liquidityPairs = try await remoteService.getAllPairs()
            
            liquidityPairs = try await liquidityPairs.asyncMap { [weak self] pair in
                let apy = try await self?.remoteService.getAPY(reservesId: pair.reservesId)
                return pair.update(apy: apy)
            }
            
            try await localPairService.sync(remotePairs: liquidityPairs)
        } catch {
            liquidityPairs = try await localPairService.get()
            throw PolkaswapServiceError.unexpectedError
        }
    }
    
    func getAllPairs() async throws -> [LiquidityPair] {
        do {
            var liquidityPairs = try await remoteService.getAllPairs()
            
            liquidityPairs = try await liquidityPairs.asyncMap { [weak self] pair in
                let apy = try await self?.remoteService.getAPY(reservesId: pair.reservesId)
                return pair.update(apy: apy)
            }
            
            try await localPairService.sync(remotePairs: liquidityPairs)
            
            return liquidityPairs
        } catch {
            return try await localPairService.get()
        }
    }
    
    func unsubscribe(id: UInt16) {
        subscriptionService.unsubscribe(id: id)
    }
    
    func unsubscribeAll() {
        subscriptionService.unsubscribeAll()
    }
}
