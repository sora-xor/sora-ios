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

    private struct PendingRefresh {
        let identifier = UUID()
        let task: Task<Result<[SbApyInfo], Swift.Error>, Never>
    }

    private var polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var apy: [SbApyInfo] = []
    private var pendingRefresh: PendingRefresh?
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

        let reservesAccountId: String? = await withCheckedContinuation { continuation in
            poolPropertiesOperation.completionBlock = {
                guard let reservesAccountData = try? poolPropertiesOperation
                    .extractResultData()?
                    .underlyingValue?
                    .reservesAccountId,
                    let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
                    continuation.resume(returning: nil)
                    return
                }

                let address = try? SS58AddressFactory().addressFromAccountId(
                    data: reservesAccountData.value,
                    type: selectedAccount.networkType
                )
                continuation.resume(returning: address)
            }

            operationManager.enqueue(operations: [poolPropertiesOperation], in: .transient)
        }

        guard let reservesAccountId else {
            return nil
        }

        let apy = await loadApy()
        return apy.first(where: { $0.id == reservesAccountId })?.sbApy?.decimalValue
    }

    private func loadApy() async -> [SbApyInfo] {
        if expiredDate > Date(), !apy.isEmpty {
            return apy
        }

        if let pendingRefresh {
            return await complete(pendingRefresh)
        }

        let refresh = createRefresh()
        pendingRefresh = refresh
        return await complete(refresh)
    }

    private func createRefresh() -> PendingRefresh {
        let operationManager = operationManager
        let baseUrl = ConfigService.shared.config.subqueryURL
        let task = Task<Result<[SbApyInfo], Swift.Error>, Never> {
            await withCheckedContinuation { continuation in
                let queryOperation = SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: baseUrl)
                queryOperation.completionBlock = {
                    continuation.resume(returning: Result {
                        try queryOperation.extractNoCancellableResultData()
                    })
                }
                operationManager.enqueue(operations: [queryOperation], in: .transient)
            }
        }

        return PendingRefresh(task: task)
    }

    private func complete(_ refresh: PendingRefresh) async -> [SbApyInfo] {
        let result = await refresh.task.value
        guard pendingRefresh?.identifier == refresh.identifier else {
            if case let .success(response) = result {
                return response
            }
            return apy
        }

        pendingRefresh = nil
        if case let .success(response) = result {
            apy = response
            expiredDate = Date().addingTimeInterval(60)
        }

        return apy
    }
}
