import Foundation
import SSFUtils
import SSFStorageQueryKit
import SSFModels

public protocol BalanceSubscriptionService {
    func createBalanceSubscription(
        accountId: Data,
        chainAsset: ChainAsset?,
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<SSFStorageQueryKit.StorageUpdate>) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) async throws -> UInt16
    
    func unsubscribe(id: UInt16, chainAsset: ChainAsset) async throws
}
