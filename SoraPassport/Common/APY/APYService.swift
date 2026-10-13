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
    private final class ContinuationGate<Value>: @unchecked Sendable {
        private enum State {
            case pending
            case waiting(CheckedContinuation<Value, Never>)
            case completed(Value)
        }

        private let lock = NSLock()
        private var state: State = .pending

        func install(_ continuation: CheckedContinuation<Value, Never>) {
            lock.lock()
            switch state {
            case .pending:
                state = .waiting(continuation)
                lock.unlock()
            case let .completed(value):
                lock.unlock()
                continuation.resume(returning: value)
            case .waiting:
                lock.unlock()
                preconditionFailure("A continuation may only be installed once")
            }
        }

        func resume(returning value: Value) {
            lock.lock()
            switch state {
            case .pending:
                state = .completed(value)
                lock.unlock()
            case let .waiting(continuation):
                state = .completed(value)
                lock.unlock()
                continuation.resume(returning: value)
            case .completed:
                lock.unlock()
            }
        }
    }

    private struct RequestKey: Hashable {
        let baseAssetId: String
        let targetAssetId: String
        let accountAddress: String
        let factoryIdentifier: ObjectIdentifier
    }

    private struct RequestFlight {
        let id: UUID
        let task: Task<Decimal?, Never>
    }

    private struct CatalogRefresh {
        let id: UUID
        let task: Task<[PIExactApyInfo], Swift.Error>
    }

    static let shared = APYService()

    private static let cacheLifetime: TimeInterval = 60
    private static let failureRetryDelay: TimeInterval = 10

    private var polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private let client = PIIndexerClient()
    private let operationManager: OperationManager = OperationManager()
    private var nextRefreshDate: Date = .distantPast
    private var apy: [PIExactApyInfo] = []
    private var hasValidatedSnapshot = false
    private var catalogRefresh: CatalogRefresh?
    private var requestFlights: [RequestKey: RequestFlight] = [:]
}

extension APYService: APYServiceProtocol {
    
    func setup(factory: PolkaswapNetworkOperationFactoryProtocol) {
        if let currentFactory = polkaswapNetworkOperationFactory,
           ObjectIdentifier(currentFactory) != ObjectIdentifier(factory) {
            requestFlights.values.forEach { $0.task.cancel() }
            requestFlights.removeAll()
        }
        polkaswapNetworkOperationFactory = factory
    }

    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal? {
        guard !baseAssetId.isEmpty,
              !targetAssetId.isEmpty,
              let factory = self.polkaswapNetworkOperationFactory,
              let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            return nil
        }
        let networkType = selectedAccount.networkType

        let key = RequestKey(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            accountAddress: selectedAccount.address,
            factoryIdentifier: ObjectIdentifier(factory)
        )
        if let flight = requestFlights[key] {
            return await flight.task.value
        }

        let flight = RequestFlight(
            id: UUID(),
            task: Task { [weak self] in
                guard let self else {
                    return nil
                }
                return await self.loadApy(
                    for: baseAssetId,
                    targetAssetId: targetAssetId,
                    factory: factory,
                    networkType: networkType
                )
            }
        )
        requestFlights[key] = flight

        let result = await flight.task.value
        if requestFlights[key]?.id == flight.id {
            requestFlights.removeValue(forKey: key)
        }
        return result
    }

    private func loadApy(
        for baseAssetId: String,
        targetAssetId: String,
        factory: PolkaswapNetworkOperationFactoryProtocol,
        networkType: SNAddressType
    ) async -> Decimal? {
        guard let catalog = await loadCatalog(), !catalog.isEmpty else {
            return nil
        }

        guard
            let poolPropertiesOperation = try? factory.poolProperties(
                baseAsset: baseAssetId,
                targetAsset: targetAssetId
            )
        else {
            return nil
        }

        // PI itself is fully async. Only the authoritative legacy runtime
        // storage lookup still crosses an Operation boundary. The gate lets
        // cancellation and Operation completion race without double-resuming
        // or stranding the checked continuation.
        let gate = ContinuationGate<String?>()
        let reservesAccountId: String? = await withTaskCancellationHandler(
            operation: {
                await withCheckedContinuation { continuation in
                    gate.install(continuation)
                    guard !Task.isCancelled else {
                        poolPropertiesOperation.cancel()
                        gate.resume(returning: nil)
                        return
                    }
                    poolPropertiesOperation.completionBlock = {
                        guard
                            let reservesAccountData = try? poolPropertiesOperation
                                .extractResultData()?
                                .underlyingValue?
                                .reservesAccountId
                        else {
                            gate.resume(returning: nil)
                            return
                        }
                        let address = try? SS58AddressFactory().addressFromAccountId(
                            data: reservesAccountData.value,
                            type: networkType
                        )
                        gate.resume(returning: address)
                    }
                    operationManager.enqueue(
                        operations: [poolPropertiesOperation],
                        in: .transient
                    )
                }
            },
            onCancel: {
                poolPropertiesOperation.cancel()
                gate.resume(returning: nil)
            }
        )

        return catalog
            .first(where: { $0.id == reservesAccountId })?
            .sbApy?
            .decimalValue
    }

    /// Returns the last fully validated PI catalog when a refresh fails. An
    /// empty successful response is cached as a valid snapshot, while an
    /// initial failure remains distinguishable from that valid empty state.
    private func loadCatalog() async -> [PIExactApyInfo]? {
        if Date() < nextRefreshDate {
            return hasValidatedSnapshot ? apy : nil
        }

        let refresh: CatalogRefresh
        if let catalogRefresh {
            refresh = catalogRefresh
        } else {
            refresh = CatalogRefresh(
                id: UUID(),
                task: Task {
                    try await self.fetchCatalog()
                }
            )
            catalogRefresh = refresh
        }

        do {
            let response = try await refresh.task.value
            if catalogRefresh?.id == refresh.id {
                apy = response
                hasValidatedSnapshot = true
                nextRefreshDate = Date().addingTimeInterval(Self.cacheLifetime)
                catalogRefresh = nil
            }
            return response
        } catch {
            if catalogRefresh?.id == refresh.id {
                catalogRefresh = nil
                nextRefreshDate = Date().addingTimeInterval(Self.failureRetryDelay)
            }
            return hasValidatedSnapshot ? apy : nil
        }
    }

    private func fetchCatalog() async throws -> [PIExactApyInfo] {
        try await client.allPoolXYKs().map { pool in
            PIExactApyInfo(
                id: pool.id,
                sbApy: pool.strategicBonusApy
            )
        }
    }
}
