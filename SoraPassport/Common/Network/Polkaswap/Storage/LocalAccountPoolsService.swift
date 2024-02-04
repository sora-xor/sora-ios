//
//  LocalAccountPoolsService.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 2/4/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood

protocol LocalAccountPoolsService {
    func get() async throws -> [AccountPool]
    func sync(remoteAccounts: [AccountPool]) async throws
}

final class LocalAccountPairServiceImpl {
    struct Changes {
        let newOrUpdatedItems: [AccountPool]
        let removedItems: [AccountPool]
    }
    
    private let repository: AnyDataProviderRepository<AccountPool>
    private let operationManager: OperationManagerProtocol
    
    init(
        repository: AnyDataProviderRepository<AccountPool>,
        operationManager: OperationManagerProtocol
    ) {
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension LocalAccountPairServiceImpl: LocalAccountPoolsService {
    
    func get() async throws -> [AccountPool] {
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
    
    func save(accountPool: AccountPool) async throws {
        let saveOperaiton = repository.saveOperation({ [accountPool] }, { [] })
        operationManager.enqueue(operations: [saveOperaiton], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuation in
            saveOperaiton.completionBlock = {
                do {
                    try saveOperaiton.extractNoCancellableResultData()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func sync(remoteAccounts: [AccountPool]) async throws {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        
        let processingOperation: BaseOperation<Changes> = ClosureOperation {
            let remotePairs = Set(remoteAccounts)
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
            return changes.removedItems.map(\.poolId)
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
