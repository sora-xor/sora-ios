import SSFUtils

protocol PoolSubscriptionService {
    func createAccountPoolsSubscription(
        accountId: Data,
        baseAssetId: String,
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) throws -> UInt16
    
    func createPoolReservesSubscription(
        baseAssetId: String,
        targetAssetId: String,
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) throws -> UInt16
    
    func unsubscribe(id: UInt16)
    
    func unsubscribeAll()
}

final class PolkaswapPoolSubscriptionService {
    
    private let keyFactory: StorageKeyFactoryProtocol
    private let connection: JSONRPCEngine
    
    init(
        keyFactory: StorageKeyFactoryProtocol,
        connection: JSONRPCEngine
    ) {
        self.keyFactory = keyFactory
        self.connection = connection
    }
}

extension PolkaswapPoolSubscriptionService: PoolSubscriptionService {
    func createAccountPoolsSubscription(
        accountId: Data,
        baseAssetId: String,
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) throws -> UInt16 {
        let storageKey = try keyFactory.accountPoolsKeyForId(
            accountId,
            baseAssetId: Data(hex: baseAssetId)
        ).toHex(includePrefix: true)
    
        return try connection.subscribe(
            RPCMethod.storageSubscribe,
            params: [[storageKey]],
            updateClosure: updateClosure,
            failureClosure: { _, _ in }
        )
    }
    
    func createPoolReservesSubscription(
        baseAssetId: String,
        targetAssetId: String,
        updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) throws -> UInt16 {
        let storageKey = try keyFactory
            .poolReservesKey(
                baseAssetId: Data(hex: baseAssetId),
                targetAssetId: Data(hex: targetAssetId)
            )
            .toHex(includePrefix: true)
    
        return try connection.subscribe(
            RPCMethod.storageSubscribe,
            params: [[storageKey]],
            updateClosure: updateClosure,
            failureClosure: { _, _ in }
        )
    }
    
    func unsubscribe(id: UInt16) {
        connection.unsubsribe(id)
    }
    
    func unsubscribeAll() {
        connection.unsubsribeAll()
    }
}
