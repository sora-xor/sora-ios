//
//  LocalPolkaswapPoolService.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/3/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood

protocol LocalLiquidityPairService {
    func get() async throws -> [LiquidityPair]
    func sync(remotePairs: [LiquidityPair]) async throws
}

final class LocalLiquidityPairServiceImpl {
    struct Changes {
        let newOrUpdatedItems: [LiquidityPair]
        let removedItems: [LiquidityPair]
    }
    
    private let repository: AnyDataProviderRepository<LiquidityPair>
    private let operationManager: OperationManagerProtocol
    
    init(
        repository: AnyDataProviderRepository<LiquidityPair>,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension LocalLiquidityPairServiceImpl: LocalLiquidityPairService {
    
    func get() async throws -> [LiquidityPair] {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationManager.enqueue(operations: [fetchOperation], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuation in
            fetchOperation.completionBlock = {
                do {
                    let localPairs = try fetchOperation.extractNoCancellableResultData()
                    continuation.resume(returning: localPairs)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func sync(remotePairs: [LiquidityPair]) async throws {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        
        let processingOperation: BaseOperation<Changes> = ClosureOperation {
            let remotePairs = Set(remotePairs)
            let localPairs = Set(try fetchOperation.extractNoCancellableResultData())
            let newOrUpdatedItems = remotePairs.subtracting(localPairs)
            let removedItems = localPairs.subtracting(remotePairs)
            return Changes(newOrUpdatedItems: Array(newOrUpdatedItems), removedItems: Array(removedItems))
        }
        
        let localSaveOperation = repository.saveOperation({
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems
        }, {
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.pairId)
        })
        
        processingOperation.addDependency(fetchOperation)
        localSaveOperation.addDependency(processingOperation)

        operationManager.enqueue(operations: [fetchOperation, processingOperation, localSaveOperation], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuation in
            localSaveOperation.completionBlock = {
                do {
                    try localSaveOperation.extractNoCancellableResultData()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
