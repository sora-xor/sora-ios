import Foundation
import RobinHood

extension WalletNetworkFacade {
    func getPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        let processingOperation: BaseOperation<[PoolDetails]> = ClosureOperation {
            let baseAsset = WalletAssetId.xor.rawValue
            let address: AccountAddress = self.address
            let operationQueue = OperationQueue()

            var poolsDetails: [PoolDetails] = []

            // accountPoolsOperation
            let accountPoolsOperation = try self.polkaswapNetworkOperationFactory.accountPools(accountId: address.accountId!)
            operationQueue.addOperations([accountPoolsOperation], waitUntilFinished: true)

            guard let pools = try accountPoolsOperation.extractResultData()?.underlyingValue?.assetIds else {
                return []
            }

            for targetAsset in pools {
                // poolProperties
                let poolPropertiesOperation = try self.polkaswapNetworkOperationFactory.poolProperties(baseAsset: baseAsset, targetAsset: targetAsset)
                operationQueue.addOperations([poolPropertiesOperation], waitUntilFinished: true)

                guard let reservesAccountId = try poolPropertiesOperation.extractResultData()?.underlyingValue?.reservesAccountId else {
                    throw NSError(domain: "Error: No pool properties", code: -1, userInfo: nil)
                }

                // poolProviders
                let poolProvidersBalanceOperation = try self.polkaswapNetworkOperationFactory.poolProvidersBalance(
                    reservesAccountId: reservesAccountId.value,
                    accountId: address.accountId!
                )
                operationQueue.addOperations([poolProvidersBalanceOperation], waitUntilFinished: true)

                guard let accountPoolBalance = try poolProvidersBalanceOperation.extractResultData()?.underlyingValue else {
                    throw NSError(domain: "Error: No account Pool Balance", code: -1, userInfo: nil)
                }

                // totalIssuances
                let accountPoolTotalIssuancesOperation = try self.polkaswapNetworkOperationFactory.poolTotalIssuances(reservesAccountId: reservesAccountId.value)
                operationQueue.addOperations([accountPoolTotalIssuancesOperation], waitUntilFinished: true)

                guard let totalIssuances = try accountPoolTotalIssuancesOperation.extractResultData()?.underlyingValue else {
                    throw NSError(domain: "Error: No total Issuances", code: -1, userInfo: nil)
                }

                // reserves
                let reservesOperation = try self.polkaswapNetworkOperationFactory.poolReserves(baseAsset: baseAsset, targetAsset: targetAsset)
                operationQueue.addOperations([reservesOperation], waitUntilFinished: true)

                guard let reserves = try reservesOperation.extractResultData()?.underlyingValue else {
                    throw NSError(domain: "Error: No reserves", code: -1, userInfo: nil)
                }

                // XOR Pooled
                let yourPoolShare = Double(accountPoolBalance.value) / Double(totalIssuances.value) * 100
                let xorPooled = Double(reserves.reserves.value * accountPoolBalance.value) / Double(totalIssuances.value)
                let targetPooled = Double(reserves.fees.value * accountPoolBalance.value) / Double(totalIssuances.value)

                let service = SubqueryPoolsFactory(url: WalletAssetId.subqueryHistoryUrl, filter: [])
                let strategicBonusAPYOperation = service.getStrategicBonusAPYOperation()
                strategicBonusAPYOperation.start()

                guard let result = try? strategicBonusAPYOperation.extractNoCancellableResultData() else { return [] }

                let sbAPYL = Double(result.edges.first(where: { $0.node.targetAssetId == targetAsset })?.node.strategicBonusApy ?? "0.0")!

                poolsDetails.append(PoolDetails(
                    targetAsset: targetAsset,
                    yourPoolShare: yourPoolShare,
                    sbAPYL: sbAPYL,
                    xorPooled: xorPooled,
                    targetAssetPooled: targetPooled
                ))
            }

            return poolsDetails
        }

        return CompoundOperationWrapper(targetOperation: processingOperation)
    }
}
