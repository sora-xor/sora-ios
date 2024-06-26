// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import SSFUtils
import Foundation
import Kingfisher

let xorDexID: UInt32 = 0
let xstusdDexID: UInt32 = 1

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
    func poolProvidersBalance() throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>>
    func poolTotalIssuances() throws -> JSONRPCListOperation<JSONScaleDecodable<Balance>>
    func poolReserves(baseAsset: String, targetAsset: String) throws -> JSONRPCListOperation<JSONScaleDecodable<PoolReserves>>
    func isPairEnabled(dexId: UInt32, assetId: String, tokenAddress: String) -> JSONRPCOperation<[JSONAny], Bool>
}

final class PolkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol {
    func dexId(for baseAssetId: String) -> UInt32 {
        if baseAssetId == WalletAssetId.xor.rawValue || baseAssetId == WalletAssetId.kxor {
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
                    baseAssetId: Data(hex: baseAsset),
                    targetAssetId: Data(hex: targetAsset)
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
