import FearlessUtils
import Foundation
import Kingfisher

let xorDexID: UInt32 = 0
let xstusdDexID: UInt32 = 1

struct SwapValues: Decodable, Equatable {
    let amount: String
    let fee: String
    let rewards: [String]
    let route: [String]

    enum CodingKeys: String, CodingKey {
        case amount
        case fee
        case rewards
        case route
    }
}

enum FilterMode: String, CaseIterable {
    case disabled = "Disabled"
    case forbidSelected = "ForbidSelected"
    case allowSelected = "AllowSelected"
}

protocol PolkaswapNetworkOperationFactoryProtocol: AnyObject {
    var engine: JSONRPCEngine { get }
    func dexId(for baseAssetId: String) -> UInt32
    func createIsSwapPossibleOperation(dexId: UInt32,
                                       from fromAssetId: String,
                                       to toAssetId: String) -> JSONRPCOperation<[JSONAny], Bool>
    func createGetAvailableMarketAlgorithmsOperation(dexId: UInt32,
                                                     from fromAssetId: String,
                                                     to toAssetId: String) -> JSONRPCOperation<[JSONAny], [String]>
    func createRecalculationOfSwapValuesOperation(dexId: UInt32,
                                                  from fromAssetId: String,
                                                  to toAssetId: String,
                                                  amount: String,
                                                  swapVariant: SwapVariant,
                                                  liquiditySources: [String],
                                                  filterMode: FilterMode) -> JSONRPCOperation<[JSONAny], SwapValues>
    
    func accountPoolsApy(accountId: String) -> JSONRPCOperation<[String], [Data]>
    func accountPools(accountId: Data, baseAssetId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<AccountPools>>
    func poolProperties(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolProperties>>
    func poolProvidersBalance(reservesAccountId: Data, accountId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>>
    func poolTotalIssuances(reservesAccountId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>>
    func poolReserves(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>
    func isPairEnabled(dexId: UInt32, assetId: String, tokenAddress: String) -> JSONRPCOperation<[JSONAny], Bool>
}

final class PolkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol {
    func dexId(for baseAssetId: String) -> UInt32 {
        if baseAssetId == WalletAssetId.xor.rawValue {
            return xorDexID
        } else if baseAssetId == WalletAssetId.xstusd.rawValue {
            return xstusdDexID
        } else {
            assert(false)
            return 0
        }
    }

    let engine: JSONRPCEngine

    init(engine: JSONRPCEngine) {
        self.engine = engine
    }

    func createIsSwapPossibleOperation(dexId: UInt32,
                                       from fromAssetId: String,
                                       to toAssetId: String) -> JSONRPCOperation<[JSONAny], Bool> {
        let paramsArray: [JSONAny] = [JSONAny(dexId),
                                      JSONAny(fromAssetId),
                                      JSONAny(toAssetId)]

        return JSONRPCOperation<[JSONAny], Bool>(engine: engine,
                                                 method: RPCMethod.checkIsSwapPossible,
                                                 parameters: paramsArray)
    }

    func createGetAvailableMarketAlgorithmsOperation(dexId: UInt32,
                                                     from fromAssetId: String,
                                                     to toAssetId: String) -> JSONRPCOperation<[JSONAny], [String]> {
        let paramsArray: [JSONAny] = [JSONAny(dexId),
                                      JSONAny(fromAssetId),
                                      JSONAny(toAssetId)]

        return JSONRPCOperation<[JSONAny], [String]>(engine: engine,
                                                     method: RPCMethod.availableMarketAlgorithms,
                                                     parameters: paramsArray)
    }

    func createRecalculationOfSwapValuesOperation(dexId: UInt32,
                                                  from fromAssetId: String,
                                                  to toAssetId: String,
                                                  amount: String,
                                                  swapVariant: SwapVariant,
                                                  liquiditySources: [String],
                                                  filterMode: FilterMode) -> JSONRPCOperation<[JSONAny], SwapValues> {

        let paramsArray: [JSONAny] = [JSONAny(dexId),
                                      JSONAny(fromAssetId),
                                      JSONAny(toAssetId),
                                      JSONAny(amount),
                                      JSONAny(swapVariant.rawValue),
                                      JSONAny(liquiditySources),
                                      JSONAny(filterMode.rawValue)
        ]

        return JSONRPCOperation<[JSONAny], SwapValues>(engine: engine,
                                                       method: RPCMethod.recalculateSwapValues,
                                                       parameters: paramsArray)
    }

    func accountPoolsApy(accountId: String) -> JSONRPCOperation<[String], [Data]> {
        return JSONRPCOperation<[String], [Data]>(engine: engine, method: RPCMethod.accountPools, parameters: [accountId])
    }

    func accountPools(accountId: Data, baseAssetId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<AccountPools>> {
        return JSONRPCListOperation<JSONScaleDecodable<AccountPools>>(
            engine: engine,
            method: RPCMethod.getStorage, parameters: [
                try StorageKeyFactory().accountPoolsKeyForId(accountId, baseAssetId: baseAssetId).toHex(includePrefix: true)
            ]
        )
    }
    
    func poolProperties(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolProperties>> {
        return JSONRPCListOperation<JSONScaleDecodable<PoolProperties>>(
            engine: engine, method: RPCMethod.getStorage,
            parameters: [
                try StorageKeyFactory().poolPropertiesKey(
                    baseAssetId: Data(hex: baseAsset),
                    targetAssetId: Data(hex: targetAsset)
                ).toHex(includePrefix: true)
            ]
        )
    }
    
    func poolProvidersBalance(reservesAccountId: Data, accountId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>> {
        return JSONRPCListOperation<JSONScaleDecodable<Balance>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [
                try StorageKeyFactory().poolProvidersKey(
                    reservesAccountId: reservesAccountId,
                    accountId: accountId
                ).toHex(includePrefix: true)
            ]
        )
    }
    
    func poolTotalIssuances(reservesAccountId: Data) throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>> {
        JSONRPCListOperation<JSONScaleDecodable<Balance>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [
                try StorageKeyFactory().accountPoolTotalIssuancesKeyForId(reservesAccountId).toHex(includePrefix: true)
            ]
        )
    }
    
    func poolReserves(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolReserves>> {
        JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [
                try StorageKeyFactory().poolReservesKey(
                    baseAssetId: Data(hex: baseAsset),
                    targetAssetId: Data(hex: targetAsset)
                ).toHex(includePrefix: true)
            ]
        )
    }

    func isPairEnabled(dexId: UInt32, assetId: String, tokenAddress: String) -> JSONRPCOperation<[JSONAny], Bool> {
        let paramsArray: [JSONAny] = [JSONAny(dexId),
                                      JSONAny(assetId),
                                      JSONAny(tokenAddress)]
        return JSONRPCOperation<[JSONAny], Bool>(engine: engine, method: RPCMethod.isPairEnabled, parameters: paramsArray)
    }
}