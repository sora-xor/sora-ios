//
//  RemotePolkaswapPoolsService.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/2/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import IrohaCrypto

enum RemotePolkaswapPoolsServiceError: Error {
    case reservesIdNotFound
}

protocol RemotePolkaswapPoolsService {
    func getAccountPools(accountId: Data) async throws -> [AccountPool]
    func getPoolDetails(accountId: Data, baseAssetId: String, targetAssetId: String) async throws -> AccountPool
    func getAllPairs() async throws -> [LiquidityPair]
    func getAPY(reservesId: String?) async throws -> Decimal?
    func getPoolReservesId(baseAssetId: String, targetAssetId: String) async throws -> String
}

actor RemotePolkaswapPoolsServiceImpl {
    
    let worker: PolkaswapWorker
    let apyService: PolkaswapAPYService
    let addressFactory: SS58AddressFactoryProtocol
    let chain: Chain
    
    init(
        chain: Chain,
        worker: PolkaswapWorker,
        apyService: PolkaswapAPYService,
        addressFactory: SS58AddressFactoryProtocol
    ) {
        self.chain = chain
        self.worker = worker
        self.apyService = apyService
        self.addressFactory = addressFactory
    }
}

extension RemotePolkaswapPoolsServiceImpl: RemotePolkaswapPoolsService {
    
    func getAccountPools(accountId: Data) async throws -> [AccountPool] {
        let baseAssetIds = try await worker.getBaseAssetIds()

        async let accountPools = baseAssetIds.concurrentMap { [weak self] baseAssetId in
            try await self?.worker.getAccountPools(accountId: accountId, baseAssetId: baseAssetId)
        }
        
        return try await accountPools.reduce([], +)
    }
    
    func getPoolDetails(accountId: Data, baseAssetId: String, targetAssetId: String) async throws -> AccountPool {
        let reservesId = try await worker.getPoolReservesId(baseAssetId: baseAssetId, targetAssetId: targetAssetId)
        
        let accountPoolBalance = try await worker.getPoolProviderBalance(reservesId: reservesId.value, accountId: accountId)
        let totalIssuances = try await worker.getPoolTotalIssuances(reservesId: reservesId.value)
        let poolReserves = try await worker.getPoolReserves(baseAssetId: baseAssetId, targetAssetId: targetAssetId)
        
        let poolDetails = (accountPoolBalance: accountPoolBalance, totalIssuances: totalIssuances, poolReserves: poolReserves)
        
        let areThereIssuances = poolDetails.totalIssuances > 0
        let reserves = poolDetails.poolReserves.reserves ?? Decimal(0)
        let targetAssetPooledTotal = poolDetails.poolReserves.fees ?? Decimal(0)

        let accountPoolShare = areThereIssuances ? poolDetails.accountPoolBalance / poolDetails.totalIssuances * 100 : .zero
        let baseAssetPooled = areThereIssuances ? reserves * poolDetails.accountPoolBalance / poolDetails.totalIssuances : .zero
        let targetAssetPooled = areThereIssuances ? targetAssetPooledTotal * poolDetails.accountPoolBalance / poolDetails.totalIssuances : .zero
        let reservationIdString = try addressFactory.address(fromAccountId: reservesId.value, type: SNAddressType(chain: chain))
                                                             
        return AccountPool(
            poolId: "\(baseAssetId)-\(targetAssetId)",
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            baseAssetPooled: baseAssetPooled,
            targetAssetPooled: targetAssetPooled,
            accountPoolShare: accountPoolShare,
            reservesId: reservationIdString
        )
    }
    
    func getAllPairs() async throws -> [LiquidityPair] {
        let baseAssetIds = try await worker.getBaseAssetIds()

        async let poolReserves = try baseAssetIds.concurrentMap { [weak self] baseAssetId in
            try await self?.worker.getPoolsReserves(baseAssetId: baseAssetId)
        }

        return try await poolReserves.reduce([], +)
    }

    func getAPY(reservesId: String?) async throws -> Decimal? {
        guard let reservesId else {
            throw RemotePolkaswapPoolsServiceError.reservesIdNotFound
        }
        return try await apyService.getApy(reservesId: reservesId)
    }
    
    func getPoolReservesId(baseAssetId: String, targetAssetId: String) async throws -> String {
        let accountId = try await worker.getPoolReservesId(baseAssetId: baseAssetId, targetAssetId: targetAssetId)
        return try addressFactory.address(fromAccountId: accountId.value, type: SNAddressType(chain: chain))
    }
}
