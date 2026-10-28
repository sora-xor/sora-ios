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
import sorawallet

protocol APYServiceProtocol: Actor {
    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal?
    func setup(factory: PolkaswapNetworkOperationFactoryProtocol)
}

actor APYService {
    static let shared = APYService()
    private var polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var apy: [SbApyInfo] = []
    private var task: Task<Void, Swift.Error>?
}

extension APYService: APYServiceProtocol {
    
    func setup(factory: PolkaswapNetworkOperationFactoryProtocol) {
        polkaswapNetworkOperationFactory = factory
    }

    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal? {
        guard !baseAssetId.isEmpty,
              !targetAssetId.isEmpty,
              let factory = self.polkaswapNetworkOperationFactory,
              let poolPropertiesOperation = try? factory.poolProperties(baseAsset: baseAssetId, targetAsset: targetAssetId) else {
            return nil
        }
        
        let queryOperation = SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: ConfigService.shared.config.subqueryURL)
        
        return await withCheckedContinuation { continuation in
            queryOperation.completionBlock = { [weak self] in
                guard let self = self,
                      let reservesAccountData = try? poolPropertiesOperation.extractResultData()?.underlyingValue?.reservesAccountId,
                      let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let reservesAccountId = try? SS58AddressFactory().addressFromAccountId(data: reservesAccountData.value,
                                                                                       type: selectedAccount.networkType)
                Task {
                    let expiredDate = await self.expiredDate
                    let apy = await self.apy
                    guard expiredDate < Date() || apy.isEmpty else {
                        let apy = apy.first(where: { $0.id == reservesAccountId })
                        continuation.resume(returning: apy?.sbApy?.decimalValue)
                        return
                    }
                    
                    guard let response = try? queryOperation.extractNoCancellableResultData() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let info = response.first(where: { $0.id == reservesAccountId })
                    await self.updateApy(apy: response)
                    await self.updateExpiredDate()
                    continuation.resume(returning: info?.sbApy?.decimalValue)
                }
            }
            
            queryOperation.addDependency(poolPropertiesOperation)
            
            operationManager.enqueue(operations: [poolPropertiesOperation, queryOperation], in: .transient)
        }
    }
    
    private func updateApy(apy: [SbApyInfo]) {
        self.apy = apy
    }
    
    private func updateExpiredDate() {
        self.expiredDate = Date().addingTimeInterval(60)
    }
}
