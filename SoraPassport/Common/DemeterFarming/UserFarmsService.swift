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
import IrohaCrypto
import RobinHood
import SSFUtils
import Combine
import SSFStorageQueryKit

protocol UserFarmsServiceProtocol: Actor {
    var userFarms: AnyPublisher<[UserFarm], Never> { get }
    func subscribeUserFarms(to baseAssetId: String, targetAssetId: String) async throws
}

actor UserFarmsService {
    var userFarms: AnyPublisher<[UserFarm], Never> {
        userFarmsSubject.eraseToAnyPublisher()
    }
    
    let userFarmsSubject = PassthroughSubject<[UserFarm], Never>()
    
    weak var poolsService: PoolsServiceInputProtocol?
    private let operationManager = OperationManager()
    
    private var subscriptionIds: [UInt16] = []
    
    deinit {
        print("deinited " + String(describing: type(of: self)))
        subscriptionIds.forEach({
            let chainId = Chain.sora.genesisHash()
            try? ChainRegistryFacade.sharedRegistry.getConnection(for: chainId)?.cancelForIdentifier($0)
        })
        subscriptionIds = []
    }
}

extension UserFarmsService: UserFarmsServiceProtocol {
    
    func subscribeUserFarms(to baseAssetId: String, targetAssetId: String) async throws {
        guard let account = SelectedWalletSettings.shared.currentAccount,
              let accountId = try? SS58AddressFactory().accountId(fromAddress: account.address, type: account.networkType) else {
            return
        }
        
        let storageKey = try StorageKeyFactory().demeterFarmingUserInfo(identifier: accountId).toHex(includePrefix: true)
        
        let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
            Task { [weak self] in
                guard let self else { return }
                let userFarms = try await self.decodeUserFarms(with: update)
                let filteredUserFarms = userFarms.filter { baseAssetId == $0.baseAssetId && targetAssetId == $0.poolAssetId && $0.isFarm }
                self.userFarmsSubject.send(filteredUserFarms)
            }
        }
        
        let failureClosure: (Swift.Error, Bool) -> Void = { error, _ in
        }
        
        let chainId = Chain.sora.genesisHash()
        let subscriptionId = try ChainRegistryFacade.sharedRegistry.getConnection(for: chainId)?.subscribe(RPCMethod.storageSubscribe,
                                                                                                           params: [[storageKey]],
                                                                                                           updateClosure: updateClosure,
                                                                                                           failureClosure: failureClosure)
        subscriptionIds.append(subscriptionId ?? 0)
    }
    
    private func decodeUserFarms(with update: JSONRPCSubscriptionUpdate<StorageUpdate>) async throws -> [UserFarm] {
        let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
        let fetchCoderFactoryOperation = runtimeService!.fetchCoderFactoryOperation()
        
        let decodingOperation = StorageFallbackDecodingListOperation<[UserFarmInfo]>(path: .demeterFarmingUserInfo)
        decodingOperation.addDependency(fetchCoderFactoryOperation)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try fetchCoderFactoryOperation.extractNoCancellableResultData()
                decodingOperation.dataList = StorageUpdateData(update: update.params.result).changes.map(\.value)
            } catch {
                decodingOperation.result = .failure(error)
            }
        }
        operationManager.enqueue(operations: [fetchCoderFactoryOperation, decodingOperation], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuetion in
            decodingOperation.completionBlock = {
                do {
                    let result = try decodingOperation.extractNoCancellableResultData()
                    let farms = result.first??.map {
                        UserFarm(
                            id: "\($0.baseAsset.value)-\($0.poolAsset.value)-\($0.rewardAsset.value)",
                            baseAssetId: $0.baseAsset.value,
                            poolAssetId: $0.poolAsset.value,
                            rewardAssetId: $0.rewardAsset.value,
                            isFarm: $0.isFarm,
                            pooledTokens: Decimal.fromSubstrateAmount($0.pooledTokens, precision: 18) ?? .zero,
                            rewards: Decimal.fromSubstrateAmount($0.rewards, precision: 18) ?? .zero
                        )
                    }
                    continuetion.resume(returning: farms ?? [])
                } catch {
                }
            }
        }
    }
}
