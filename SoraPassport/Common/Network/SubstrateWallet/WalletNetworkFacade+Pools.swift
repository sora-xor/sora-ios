import Foundation
import RobinHood
import BigInt
import FearlessUtils
import XNetworking

enum PoolError: Swift.Error {
    case noProperties
    case noReserves
}


extension WalletNetworkFacade {
    func getPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        let processingOperation: BaseOperation<[PoolDetails]> = ClosureOperation { [weak self] in
            var poolsDetails: [PoolDetails] = []
            guard let weakSelf = self else { return poolsDetails }

            let accountPools = weakSelf.loadAccountPools()
            poolsDetails = weakSelf.loadPoolsDetails(accountPools: accountPools)
            poolsDetails = weakSelf.sort(poolDetails: poolsDetails)

            return poolsDetails
        }

        return CompoundOperationWrapper(targetOperation: processingOperation)
    }

    fileprivate func loadAccountPools() -> [String: [String]] {
        var pools: [String: [String]] = [:]
        let baseAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
        for baseAssetId in baseAssetIds {
            if let baseAssetIdData = try? Data(hexString: baseAssetId),
               let assetPoolList = self.poolList(baseAssetId: baseAssetIdData) {
                pools[baseAssetId] = assetPoolList
            }
        }
        return pools
    }

    fileprivate func loadPoolsDetails(accountPools: [String: [String]]) -> [PoolDetails] {
        var poolsDetails: [PoolDetails] = []
        let strategicBonusAPYOperation = SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: ConfigService.shared.config.subqueryURL)

        OperationQueue().addOperations([strategicBonusAPYOperation], waitUntilFinished: true)

        let apyResult = try? strategicBonusAPYOperation.extractNoCancellableResultData()

        for pool in accountPools {
            for targetAsset in pool.value {
                do {
                    var poolDetails = try getPoolDetails(baseAsset: pool.key, targetAsset: targetAsset)
                    let info = apyResult?.first(where: { $0.id == targetAsset })
                    poolDetails.sbAPYL = Double(info?.sbApy ?? 0)
                    poolsDetails.append(poolDetails)
                } catch {
                    print(error)
                }
            }
        }
        return poolsDetails
    }

    fileprivate func sort(poolDetails: [PoolDetails]) -> [PoolDetails] {
        poolDetails.sorted(by: { poolDetails1, poolDetails2 in
            return poolDetails1.baseAsset < poolDetails2.baseAsset
        })
    }

    fileprivate func poolList(baseAssetId: Data) -> [String]? {
        let operationQueue = OperationQueue()
        guard let operation = try? polkaswapNetworkOperationFactory.accountPools(accountId: address.accountId!, baseAssetId: baseAssetId) else {
            return nil
        }
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try? operation.extractResultData()?.underlyingValue?.assetIds
    }

    func getPoolDetails(baseAsset: String, targetAsset: String) throws -> PoolDetails {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .utility
        // poolProperties
        let poolPropertiesOperation = try self.polkaswapNetworkOperationFactory.poolProperties(baseAsset: baseAsset, targetAsset: targetAsset)
        operationQueue.addOperations([poolPropertiesOperation], waitUntilFinished: true)

        guard let reservesAccountId = try poolPropertiesOperation.extractResultData()?.underlyingValue?.reservesAccountId else {
            throw PoolError.noProperties
        }

        // poolProviders
        let poolProvidersBalanceOperation = try self.polkaswapNetworkOperationFactory.poolProvidersBalance(
            reservesAccountId: reservesAccountId.value,
            accountId: address.accountId!
        )
        operationQueue.addOperations([poolProvidersBalanceOperation], waitUntilFinished: true)

        let accountPoolBalance = try poolProvidersBalanceOperation.extractResultData()?.underlyingValue ?? Balance(value: BigUInt(0))

        // totalIssuances
        let accountPoolTotalIssuancesOperation = try self.polkaswapNetworkOperationFactory.poolTotalIssuances(
            reservesAccountId: reservesAccountId.value
        )
        operationQueue.addOperations([accountPoolTotalIssuancesOperation], waitUntilFinished: true)

        let totalIssuances = try accountPoolTotalIssuancesOperation.extractResultData()?.underlyingValue ?? Balance(value: BigUInt(0))

        // reserves
        let reservesOperation = try self.polkaswapNetworkOperationFactory.poolReserves(baseAsset: baseAsset, targetAsset: targetAsset)
        operationQueue.addOperations([reservesOperation], waitUntilFinished: true)

        guard let reserves = try reservesOperation.extractResultData()?.underlyingValue else {
            throw PoolError.noReserves
        }

        let accountPoolBalanceDecimal = Decimal.fromSubstrateAmount(accountPoolBalance.value, precision: 18) ?? .zero
        let reservesDecimal = Decimal.fromSubstrateAmount(reserves.reserves.value, precision: 18) ?? .zero
        let totalIssuancesDecimal = Decimal.fromSubstrateAmount(totalIssuances.value, precision: 18) ?? .zero
        let targetAssetPooledTotalDecimal = Decimal.fromSubstrateAmount(reserves.fees.value, precision: 18) ?? .zero

        // XOR Pooled
        let yourPoolShare = totalIssuances.value > 0 ? accountPoolBalanceDecimal / totalIssuancesDecimal * 100 : .zero
        let xorPooled = totalIssuances.value > 0 ? reservesDecimal * accountPoolBalanceDecimal / totalIssuancesDecimal : .zero
        let targetPooled = totalIssuances.value > 0 ? targetAssetPooledTotalDecimal * accountPoolBalanceDecimal / totalIssuancesDecimal : .zero

        return PoolDetails(
            baseAsset: baseAsset,
            targetAsset: targetAsset,
            yourPoolShare: yourPoolShare,
            sbAPYL: 0,
            baseAssetPooledByAccount: xorPooled,
            targetAssetPooledByAccount: targetPooled,
            baseAssetPooledTotal: reservesDecimal,
            targetAssetPooledTotal: targetAssetPooledTotalDecimal,
            totalIssuances: Decimal.fromSubstrateAmount(totalIssuances.value, precision: 18) ?? 0.0,
            baseAssetReserves: Decimal.fromSubstrateAmount(reserves.reserves.value, precision: 18) ?? 0.0,
            targetAssetReserves: Decimal.fromSubstrateAmount(reserves.fees.value, precision: 18) ?? 0.0
        )
    }
}
