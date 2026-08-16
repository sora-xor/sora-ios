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
import RobinHood
import sorawallet

protocol FiatServiceObserverProtocol: AnyObject {
    func processFiat(data: [FiatData])
}

protocol FiatServiceProtocol: AnyObject {
    func getFiat() async -> [FiatData]
    func getFiat(for assetIds: [String]) async -> [FiatData]
}

struct FiatServiceObserver {
    weak var observer: FiatServiceObserverProtocol?
}

actor FiatService {
    static let shared = FiatService()

    private struct PendingRefresh {
        let identifier = UUID()
        let assetIds: Set<String>
        let task: Task<Result<[FiatData], Swift.Error>, Never>
    }

    private let operationManager: OperationManager = OperationManager()
    private var fiatDataByAssetId: [String: FiatData] = [:]
    private var expirationByAssetId: [String: Date] = [:]
    private var pendingRefresh: PendingRefresh?

    private func currentAssetIds() -> [String] {
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(
            for: Chain.sora.genesisHash()
        )
        return (assetManager.getAssetList() ?? []).map(\.assetId)
    }

    private func createRefresh(for assetIds: Set<String>) -> PendingRefresh {
        let sortedAssetIds = assetIds.sorted()
        let operationManager = operationManager
        let baseUrl = ConfigService.shared.config.subqueryURL
        let task = Task<Result<[FiatData], Swift.Error>, Never> {
            await withCheckedContinuation { continuation in
                let queryOperation = SubqueryFiatInfoOperation<[FiatData]>(
                    baseUrl: baseUrl,
                    assetIds: sortedAssetIds
                )
                queryOperation.completionBlock = {
                    continuation.resume(returning: Result {
                        try queryOperation.extractNoCancellableResultData()
                    })
                }
                operationManager.enqueue(operations: [queryOperation], in: .transient)
            }
        }

        return PendingRefresh(assetIds: assetIds, task: task)
    }

    private func complete(_ refresh: PendingRefresh) async -> Bool {
        let result = await refresh.task.value

        guard pendingRefresh?.identifier == refresh.identifier else {
            if case .failure = result {
                return false
            }
            return true
        }
        pendingRefresh = nil

        switch result {
        case let .success(response):
            refresh.assetIds.forEach { fiatDataByAssetId[$0] = nil }
            response.forEach { fiatDataByAssetId[$0.id] = $0 }
            let expirationDate = Date().addingTimeInterval(600)
            refresh.assetIds.forEach { expirationByAssetId[$0] = expirationDate }
            Logger.shared.info(
                "SORA fiat prices loaded: \(response.count)/\(refresh.assetIds.count)"
            )
            return true
        case .failure:
            Logger.shared.error("SORA fiat price refresh failed")
            return false
        }
    }

    private func cachedFiatData(for assetIds: Set<String>) -> [FiatData] {
        assetIds.compactMap { fiatDataByAssetId[$0] }.sorted { $0.id < $1.id }
    }
}

extension FiatService: FiatServiceProtocol {
    func getFiat() async -> [FiatData] {
        let assetIds = currentAssetIds()
        guard !assetIds.isEmpty else {
            return fiatDataByAssetId.values.sorted { $0.id < $1.id }
        }
        return await getFiat(for: assetIds)
    }

    func getFiat(for assetIds: [String]) async -> [FiatData] {
        let requestedAssetIds = Set(assetIds.filter {
            $0.range(of: #"^0x[0-9a-fA-F]{64}$"#, options: .regularExpression) != nil
        })
        guard !requestedAssetIds.isEmpty else {
            return []
        }

        while true {
            let currentDate = Date()
            let missingAssetIds = requestedAssetIds.filter {
                (expirationByAssetId[$0] ?? .distantPast) <= currentDate
            }
            guard !missingAssetIds.isEmpty else {
                return cachedFiatData(for: requestedAssetIds)
            }

            if let pendingRefresh {
                guard await complete(pendingRefresh) else {
                    return cachedFiatData(for: requestedAssetIds)
                }
                continue
            }

            let refresh = createRefresh(for: Set(missingAssetIds))
            pendingRefresh = refresh
            guard await complete(refresh) else {
                return cachedFiatData(for: requestedAssetIds)
            }
        }
    }
}
