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
