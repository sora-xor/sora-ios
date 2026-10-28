// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SSFUtils
import Foundation
import Kingfisher

struct SwapValues: Decodable, Equatable {
    let amount: String
    let route: [String]

    enum CodingKeys: String, CodingKey {
        case amount
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
    func poolProvidersBalance() throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>>
    func poolTotalIssuances() throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>>
    func poolReserves(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>
    func isPairEnabled(dexId: UInt32, assetId: String, tokenAddress: String) -> JSONRPCOperation<[JSONAny], Bool>
}

/// DEX ids come from `DexInfoService`, which reads them from the chain.
final class PolkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol {
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
            method: RPCMethod.getStorage, 
            parameters: [
                try StorageKeyFactory().accountPoolsKeyForId(accountId, baseAssetId: baseAssetId).toHex(includePrefix: true)
            ]
        )
    }
    
    func poolProperties(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolProperties>> {
        return JSONRPCListOperation<JSONScaleDecodable<PoolProperties>>(
            engine: engine, method: RPCMethod.getStorage,
            parameters: [
                try StorageKeyFactory().poolPropertiesKey(
                    baseAssetId: Data.sora(hex: baseAsset),
                    targetAssetId: Data.sora(hex: targetAsset)
                ).toHex(includePrefix: true)
            ]
        )
    }
    
    func poolProvidersBalance() throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>> {
        return JSONRPCListOperation<JSONScaleDecodable<Balance>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: []

        )
    }
    
    func poolTotalIssuances() throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>> {
        JSONRPCListOperation<JSONScaleDecodable<Balance>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: []
        )
    }
    
    func poolReserves(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolReserves>> {
        JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>(
            engine: engine,
            method: RPCMethod.getStorage,
            parameters: [
                try StorageKeyFactory().poolReservesKey(
                    baseAssetId: Data.sora(hex: baseAsset),
                    targetAssetId: Data.sora(hex: targetAsset)
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
