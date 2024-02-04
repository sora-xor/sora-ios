//
//  PoolService.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/3/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation

enum PolkaswapServiceError: Error {
    case unexpectedError
}

protocol PoolsService {
    var pairsPublisher: Published<[LiquidityPair]>.Publisher { get }
    func subscribeAllPairs() async throws
    
    var accountPoolsPublisher: Published<[AccountPool]>.Publisher { get }
    func subscribeAccountPools(accountId: Data) async throws
    
    var poolDetailsPublisher: Published<AccountPool?>.Publisher { get }
    func getAccountPoolDetails(accountId: Data, baseAssetId: String, targetAssetId: String) async throws
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
    
    init(
        remoteService: RemotePolkaswapPoolsService,
        localPairService: LocalLiquidityPairService,
        localAccountPoolService: LocalAccountPoolsService
    ) {
        self.remoteService = remoteService
        self.localPairService = localPairService
        self.localAccountPoolService = localAccountPoolService
    }
}

extension PolkaswapService: PoolsService {
    func subscribeAccountPools(accountId: Data) async throws {
        do {
            accountPools = try await remoteService.getAccountPools(accountId: accountId)
            
            accountPools = try await accountPools.asyncMap { [weak self] pool in
                let apy = try await self?.remoteService.getAPY(reservesId: pool.reservesId)
                return pool.update(apy: apy)
            }
            
            try await localAccountPoolService.sync(remoteAccounts: accountPools)
        } catch {
            accountPools = try await localAccountPoolService.get()
            throw PolkaswapServiceError.unexpectedError
        }
    }
    
    func getAccountPoolDetails(accountId: Data, baseAssetId: String, targetAssetId: String) async throws {
        do {
            poolDetails = try await remoteService.getPoolDetails(accountId: accountId, baseAssetId: baseAssetId, targetAssetId: targetAssetId)
            try await localAccountPoolService.sync(remoteAccounts: accountPools)
        } catch {
            let pools = try? await localAccountPoolService.get()
            poolDetails = pools?.first { $0.baseAssetId == baseAssetId && $0.targetAssetId == targetAssetId }
            throw PolkaswapServiceError.unexpectedError
        }
    }
    
    func subscribeAllPairs() async throws {
        do {
            liquidityPairs = try await remoteService.getAllPairs()
            
            let pairs = try await liquidityPairs.asyncMap { [weak self] pair in
                if let reservesId = pair.reservesId {
                    return pair.update(reservesId: reservesId)
                }
                
                let reservesId = try await self?.remoteService.getPoolReservesId(baseAssetId: pair.baseAssetId, targetAssetId: pair.targetAssetId)
                return pair.update(reservesId: reservesId)
            }
            
            liquidityPairs = try await pairs.asyncMap { [weak self] pair in
                let apy = try await self?.remoteService.getAPY(reservesId: pair.reservesId)
                return pair.update(apy: apy)
            }
            
            try await localPairService.sync(remotePairs: pairs)
        } catch {
            liquidityPairs = try await localPairService.get()
            throw PolkaswapServiceError.unexpectedError
        }
    }
}
