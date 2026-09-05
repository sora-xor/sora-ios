import Foundation
import SSFBalances
import SSFChainConnection
import SSFChainRegistry
import SSFModels
import SSFStorageQueryKit
import SSFUtils

public final class SubstrateBalanceSubscriptionService {
    private let keyFactory: StorageKeyFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol

    public init(
        keyFactory: StorageKeyFactoryProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.keyFactory = keyFactory
        self.chainRegistry = chainRegistry
    }
}

extension SubstrateBalanceSubscriptionService: BalanceSubscriptionService {
    public func createBalanceSubscription(
        accountId: Data,
        chainAsset: SSFModels.ChainAsset?,
        updateClosure: @escaping (
            SSFUtils
                .JSONRPCSubscriptionUpdate<SSFStorageQueryKit.StorageUpdate>
        ) -> Void,
        failureClosure: @escaping (any Error, Bool) -> Void
    ) async throws -> UInt16 {
        let connection: SubstrateConnection = try await chainRegistry
            .getSubstrateConnection(for: chainAsset!.chain)

        var storageKey = try keyFactory.systemAccountKeyForId(
            accountId
        ).toHex(includePrefix: true)

        if let assetId = chainAsset?.asset.tokenProperties?.currencyId {
            storageKey = try keyFactory.tokensAccountsKeyForId(
                accountId,
                assetId: Data(hex: assetId)
            ).toHex(includePrefix: true)
        }

        return try connection.subscribe(
            RPCMethod.storageSubscribe,
            params: [[storageKey]],
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    public func unsubscribe(id _: UInt16, chainAsset _: SSFModels.ChainAsset) throws {}
}
