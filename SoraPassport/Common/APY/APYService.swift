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
