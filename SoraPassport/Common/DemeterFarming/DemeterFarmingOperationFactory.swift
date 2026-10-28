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

import Foundation
import SSFUtils
import BigInt
import RobinHood

final class DemeterFarmingOperationFactory {
    let engine: JSONRPCEngine
    
    init(engine: JSONRPCEngine) {
        self.engine = engine
    }
    
    func userInfo(accountId: Data,
                  runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) throws -> CompoundOperationWrapper<[UserFarmInfo]> {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let eventsWrapper: CompoundOperationWrapper<[StorageResponse<[UserFarmInfo]>]> =
        storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { return try runtimeOperation.extractNoCancellableResultData() },
            storagePath: .demeterFarmingUserInfo
        )
        
        eventsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }
        
        let mapOperation = ClosureOperation<[UserFarmInfo]> {
            try eventsWrapper.targetOperation.extractNoCancellableResultData().first?.value ?? []
        }

        mapOperation.addDependency(eventsWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [runtimeOperation] + eventsWrapper.allOperations)
    }
    
    func poolsKeysPagedOperation() throws -> JSONRPCOperation<[JSONAny], [String]> {
        let poolsKey = try StorageKeyFactory().demeterFarmingPoolsKeysPaged().toHex()
        
        let keyPageSize: UInt32 = 100
        let paramsArray: [JSONAny] = [ JSONAny(poolsKey), JSONAny(keyPageSize) ]
        
        return JSONRPCOperation<[JSONAny], [String]>(
            engine: engine,
            method: RPCMethod.getStorageKeysPaged,
            parameters: paramsArray)
    }
    
    func poolsOperation(poolAssetId: String, rewardAssetId: String,
                        runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) throws -> CompoundOperationWrapper<[FarmedPoolInfo]> {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let storageOperation: CompoundOperationWrapper<[StorageResponse<[FarmedPoolInfo]>]> =
        storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [ AssetId(wrappedValue: poolAssetId), AssetId(wrappedValue: rewardAssetId) ] },
            factory: { return try runtimeOperation.extractNoCancellableResultData() },
            storagePath: .demeterFarmingPools
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mapOperation = ClosureOperation<[FarmedPoolInfo]> {
            try storageOperation.targetOperation.extractNoCancellableResultData().first?.value ?? []
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [runtimeOperation] + storageOperation.allOperations)
    }
    
    func tokenInfosKeysPagedOperation() throws -> JSONRPCOperation<[JSONAny], [String]> {
        let tokenInfosKey = try StorageKeyFactory().demeterFarmingTokenInfosKeysPaged().toHex()
        
        let keyPageSize: UInt32 = 100
        let paramsArray: [JSONAny] = [ JSONAny(tokenInfosKey), JSONAny(keyPageSize) ]
        
        return JSONRPCOperation<[JSONAny], [String]>(
            engine: engine,
            method: RPCMethod.getStorageKeysPaged,
            parameters: paramsArray)
    }
    
    func tokenInfos(assetId: String, runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) throws -> CompoundOperationWrapper<FarmedTokenInfo?> {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let storageOperation: CompoundOperationWrapper<[StorageResponse<FarmedTokenInfo?>]> =
        storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [ AssetId(wrappedValue: assetId) ] },
            factory: { return try runtimeOperation.extractNoCancellableResultData() },
            storagePath: .demeterFarmingTokenInfo
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(runtimeOperation) }

        let mapOperation = ClosureOperation<FarmedTokenInfo?> {
            try storageOperation.targetOperation.extractNoCancellableResultData().first?.value ?? nil
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [runtimeOperation] + storageOperation.allOperations)
    }
}
