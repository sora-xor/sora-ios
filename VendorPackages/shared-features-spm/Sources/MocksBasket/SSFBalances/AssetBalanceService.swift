import Foundation
import SSFBalances
import SSFStorageQueryKit
import SSFModels
import Combine
import SSFAssetManagment
import SSFUtils

enum AssetBalanceServiceError: Error {
    case notFound
}

public struct AssetBalanceSubscriptionId {
    let subscriptionId: UInt16
    let chainAsset: ChainAsset
}

public protocol AssetBalanceService: Actor {
    func getBalance(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> AssetBalanceInfo
    
    func getBalances(
        for chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> [AssetBalanceInfo]

    func getBalances(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [AssetBalanceInfo]

    func getBalances(
        for chains: [ChainModel],
        accountId: AccountId
    ) async throws -> [AssetBalanceInfo]
    
    func subscribeBalance(
        on chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> (id: AssetBalanceSubscriptionId, publisher: PassthroughSubject<AssetBalanceInfo, Error>)
    
    func subscribeBalances(
        on chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> (ids: [AssetBalanceSubscriptionId], publisher: PassthroughSubject<[AssetBalanceInfo], Error>)

    func subscribeBalances(
        on chain: ChainModel,
        accountId: AccountId
    ) async throws -> (ids: [AssetBalanceSubscriptionId], publisher: PassthroughSubject<[AssetBalanceInfo], Error>)
    
    func subscribeBalances(
        on chains: [ChainModel],
        accountId: AccountId
    ) async throws -> (ids: [AssetBalanceSubscriptionId], publisher: PassthroughSubject<[AssetBalanceInfo], Error>)

    func unsubscribe(ids: [AssetBalanceSubscriptionId]) async throws
}


public actor AssetBalanceServiceDefault {
    let remoteService: AccountInfoRemoteService
    let subscriptionService: BalanceSubscriptionService
    
    public init(remoteService: AccountInfoRemoteService,
         subscriptionService: BalanceSubscriptionService
    ) {
        self.remoteService = remoteService
        self.subscriptionService = subscriptionService
    }
}

extension AssetBalanceServiceDefault: AssetBalanceService {
    
    public func getBalance(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> AssetBalanceInfo {
        guard let accountInfo = try await remoteService.fetchAccountInfo(
            for: chainAsset,
            accountId: accountId
        ) else {
            throw AssetBalanceServiceError.notFound
        }
        
        let balance = Decimal.fromSubstrateAmount(
            accountInfo.data.sendAvailable,
            precision: Int16(chainAsset.asset.precision)
        )
        
        let lockedBalance = Decimal.fromSubstrateAmount(
            accountInfo.data.locked,
            precision: Int16(chainAsset.asset.precision))
        
        return AssetBalanceInfo(
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.symbol,
            accountId: accountId.toHex(),
            price: nil,
            deltaPrice: nil,
            balance: balance,
            lockedBalance: lockedBalance
        )
    }
    
    public func getBalances(
        for chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> [AssetBalanceInfo] {
        return try await chainAssets.asyncMap { chainAsset in
            return try await getBalance(for: chainAsset, accountId: accountId)
        }
    }

    public func getBalances(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [AssetBalanceInfo] {
        let balacesMap = try await remoteService.fetchAccountInfos(for: chain, accountId: accountId)

        return balacesMap.compactMap { assetId, accountInfo in
            guard let accountInfo = accountInfo,
                  let chainAsset = chain.chainAssets.first(where: { $0.chainAssetId == assetId }) else {
                return nil
            }
            
            let balance = Decimal.fromSubstrateAmount(
                accountInfo.data.sendAvailable,
                precision: Int16(chainAsset.asset.precision)
            )
            
            let lockedBalance = Decimal.fromSubstrateAmount(
                accountInfo.data.locked,
                precision: Int16(chainAsset.asset.precision))
            
            return AssetBalanceInfo(
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.symbol,
                accountId: accountId.toHex(),
                price: nil,
                deltaPrice: nil,
                balance: balance,
                lockedBalance: lockedBalance
            )
        }
    }

    public func getBalances(
        for chains: [ChainModel],
        accountId: AccountId
    ) async throws -> [AssetBalanceInfo] {
        let balances = try await chains.asyncCompactMap { chainAsset in
            return try await getBalances(for: chainAsset, accountId: accountId)
        }
        return balances.reduce([], +)
    }
    

    public func subscribeBalance(
        on chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> (id: AssetBalanceSubscriptionId, publisher: PassthroughSubject<AssetBalanceInfo, Error>) {
        let publisher = PassthroughSubject<AssetBalanceInfo, Error>()

        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                let balance = try await self.getBalance(for: chainAsset, accountId: accountId)
                publisher.send(balance)
            }
        }
        
        let failureClosure: (Error, Bool) -> Void = { error, _ in
            publisher.send(completion: .failure(error))
        }

        let subscriptionId = try await subscriptionService.createBalanceSubscription(
            accountId: accountId,
            chainAsset: chainAsset,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
        
        let id = AssetBalanceSubscriptionId(subscriptionId: subscriptionId, chainAsset: chainAsset)
        
        return (id: id, publisher: publisher)
    }

    public func subscribeBalances(
        on chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> (ids: [AssetBalanceSubscriptionId], publisher: PassthroughSubject<[AssetBalanceInfo], Error>) {
        let publisher = PassthroughSubject<[AssetBalanceInfo], Error>()
        
        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                
                let balances = try await self.getBalances(for: chainAssets, accountId: accountId)
                publisher.send(balances)
            }
        }
        
        let failureClosure: (Error, Bool) -> Void = { error, _ in
            publisher.send(completion: .failure(error))
        }
        
        let ids = try await chainAssets.asyncCompactMap { chainAsset in
            let subscriptionId = try await subscriptionService.createBalanceSubscription(
                accountId: accountId,
                chainAsset: chainAsset,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
            
            return AssetBalanceSubscriptionId(subscriptionId: subscriptionId, chainAsset: chainAsset)
        }

        return (ids: ids, publisher: publisher)
    }

    public func subscribeBalances(
        on chain: ChainModel,
        accountId: AccountId
    ) async throws -> (ids: [AssetBalanceSubscriptionId], publisher: PassthroughSubject<[AssetBalanceInfo], Error>) {
        let publisher = PassthroughSubject<[AssetBalanceInfo], Error>()
        
        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                
                let balances = try await self.getBalances(for: chain, accountId: accountId)
                publisher.send(balances)
            }
        }
        
        let failureClosure: (Error, Bool) -> Void = { error, _ in
            publisher.send(completion: .failure(error))
        }
        
        let ids = try await chain.chainAssets.asyncCompactMap { chainAsset in
            let subscriptionId = try await subscriptionService.createBalanceSubscription(
                accountId: accountId,
                chainAsset: chainAsset,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
            
            return AssetBalanceSubscriptionId(subscriptionId: subscriptionId, chainAsset: chainAsset)
        }

        return (ids: ids, publisher: publisher)
    }

    public func subscribeBalances(
        on chains: [ChainModel],
        accountId: AccountId
    ) async throws -> (ids: [AssetBalanceSubscriptionId], publisher: PassthroughSubject<[AssetBalanceInfo], Error>) {
        let publisher = PassthroughSubject<[AssetBalanceInfo], Error>()
        
        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                
                let balances = try await self.getBalances(for: chains, accountId: accountId)
                publisher.send(balances)
            }
        }
        
        let failureClosure: (Error, Bool) -> Void = { error, _ in
            publisher.send(completion: .failure(error))
        }
        
        let assets = chains.map { $0.chainAssets }.reduce([], +)
        let ids = try await assets.asyncCompactMap { chainAsset in
            let subscriptionId = try await subscriptionService.createBalanceSubscription(
                accountId: accountId,
                chainAsset: chainAsset,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
            
            return AssetBalanceSubscriptionId(subscriptionId: subscriptionId, chainAsset: chainAsset)
        }

        return (ids: ids, publisher: publisher)
    }

    public func unsubscribe(ids: [AssetBalanceSubscriptionId]) async throws {
        try await ids.asyncForEach { id in
            try await subscriptionService.unsubscribe(id: id.subscriptionId, chainAsset: id.chainAsset)
        }
    }
}
