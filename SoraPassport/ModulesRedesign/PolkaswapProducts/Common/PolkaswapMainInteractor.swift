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
import RobinHood
import BigInt
import SSFStorageQueryKitFixed

final class PolkaswapMainInteractor {
    weak var presenter: PolkaswapMainInteractorOutputProtocol!
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let operationManager: OperationManagerProtocol // = OperationManagerFacade.sharedManager
    var eventCenter: EventCenterProtocol
    let dexService: DexInfoService

    private(set) var xykPoolSubscriptionIds: [UInt16] = []
    private(set) var tbcPoolSubscriptionIds: [UInt16] = []
    private var xykSubscriptions: [(id: UInt16, engine: JSONRPCEngine)] = []
    private var tbcSubscriptions: [(id: UInt16, engine: JSONRPCEngine)] = []
    private var xykGeneration = UUID()
    private var tbcGeneration = UUID()
    private var isObserving = false

    init(
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        dexService: DexInfoService = .shared
    ) {
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.dexService = dexService
    }

    deinit {
        stop()
    }

    func setup() {
        guard !isObserving else { return }
        isObserving = true
        eventCenter.add(observer: self)
    }

    func stop() {
        if isObserving {
            isObserving = false
            eventCenter.remove(observer: self)
        }
        unsubscribePoolXYK()
        unsubscribePoolTBC()
    }
}

struct PolkaswapMainInteractorQuoteParams {
    let fromAssetId: String
    let toAssetId: String
    let amount: String
    let swapVariant: SwapVariant
    let liquiditySources: [String]
    let filterMode: FilterMode
}

extension PolkaswapMainInteractor: PolkaswapMainInteractorInputProtocol {

    func networkFeeValue(completion: @escaping (Decimal) -> Void) {
        FeeProvider().getFee(for: .swap) { resultFee in
            completion(resultFee)
        }
    }

    /// A path is available when any DEX on the chain can route it. The result is reported
    /// only if at least one DEX answered.
    func checkIsPathAvailable(fromAssetId: String, toAssetId: String) {
        dexService.dexes { [weak self] dexes in
            guard let self, let facade = self.polkaswapNetworkFacade else { return }
            let operations = dexes.map {
                facade.createIsSwapPossibleOperation(dexId: $0.id, from: fromAssetId, to: toAssetId)
            }
            let mergeOperation: BaseOperation<Bool?> = ClosureOperation {
                let answers = operations.compactMap { try? $0.extractResultData() }
                return answers.isEmpty ? nil : answers.contains(true)
            }
            operations.forEach { mergeOperation.addDependency($0) }
            mergeOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard let self, let answer = try? mergeOperation.extractResultData(), let isAvailable = answer else {
                        return
                    }
                    self.presenter.didCheckPath(fromAssetId: fromAssetId, toAssetId: toAssetId, isAvailable: isAvailable)
                }
            }
            self.operationManager.enqueue(operations: operations + [mergeOperation], in: .blockAfter)
        }
    }

    /// The liquidity sources of every DEX that answered, in DEX order without repeats.
    func loadMarketSources(fromAssetId: String, toAssetId: String) {
        dexService.dexes { [weak self] dexes in
            guard let self, let facade = self.polkaswapNetworkFacade else { return }
            let operations = dexes.map {
                facade.createGetAvailableMarketAlgorithmsOperation(dexId: $0.id, from: fromAssetId, to: toAssetId)
            }
            let mergeOperation: BaseOperation<[String]?> = ClosureOperation {
                let answers = operations.compactMap { try? $0.extractResultData() }
                guard !answers.isEmpty else { return nil }
                var sources: [String] = []
                for source in answers.joined() where !sources.contains(source) {
                    sources.append(source)
                }
                return sources
            }
            operations.forEach { mergeOperation.addDependency($0) }
            mergeOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard let self, let answer = try? mergeOperation.extractResultData(), let sources = answer else {
                        return
                    }
                    self.presenter.didLoadMarketSources(sources, fromAssetId: fromAssetId, toAssetId: toAssetId)
                }
            }
            self.operationManager.enqueue(operations: operations + [mergeOperation], in: .blockAfter)
        }
    }

    /// Quotes on every DEX of the chain and keeps the best quote and its DEX id, which
    /// the swap is then sent with.
    func quote(params: PolkaswapMainInteractorQuoteParams) {
        dexService.dexes { [weak self] dexes in
            guard let self, let networkFacade = self.polkaswapNetworkFacade else { return }
            let operations: [(operation: JSONRPCOperation<[JSONAny], SwapValues>, dexId: UInt32)] = dexes.map { dex in
                let operation = networkFacade.createRecalculationOfSwapValuesOperation(
                    dexId: dex.id,
                    from: params.fromAssetId,
                    to: params.toAssetId,
                    amount: params.amount,
                    swapVariant: params.swapVariant,
                    liquiditySources: params.liquiditySources,
                    filterMode: params.filterMode)
                return (operation, dex.id)
            }

            let mergeOperation: BaseOperation<(quote: SwapValues?, dexId: UInt32)> = ClosureOperation {
                Self.bestQuote(
                    operations.map { (quote: try? $0.operation.extractResultData(), dexId: $0.dexId) },
                    swapVariant: params.swapVariant
                )
            }

            for operation in operations {
                mergeOperation.addDependency(operation.operation)
            }

            mergeOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, let quote = try? mergeOperation.extractResultData() else { return }
                    self.presenter.didLoadQuote(quote.quote, dexId: quote.dexId, params: params)
                }
            }
            self.operationManager.enqueue(operations: [mergeOperation] + operations.map { $0.operation }, in: .blockAfter)
        }
    }

    /// For a given input the largest output wins; for a desired output the smallest input.
    static func bestQuote(
        _ quotes: [(quote: SwapValues?, dexId: UInt32)],
        swapVariant: SwapVariant
    ) -> (quote: SwapValues?, dexId: UInt32) {
        // Runtime quotes are canonical positive u128 atomic amounts. Decimal
        // parsing can accept a numeric prefix or erase the ordering of large
        // balances; compare the validated integers without conversion.
        var best: (quote: SwapValues, dexId: UInt32, amount: BigUInt)?
        for item in quotes {
            guard let quote = item.quote else { continue }
            let digits = quote.amount.utf8
            guard !digits.isEmpty, digits.count <= 39,
                  digits.first != 48, digits.allSatisfy({ (48...57).contains($0) }),
                  let amount = BigUInt(quote.amount), amount.bitWidth <= 128 else {
                continue
            }
            if let current = best {
                let improves = swapVariant == .desiredInput
                    ? amount > current.amount : amount < current.amount
                guard improves else { continue }
            }
            best = (quote, item.dexId, amount)
        }
        return (best?.quote, best?.dexId ?? 0)
    }

    func loadBalance(asset: AssetInfo) {
        let operationManager = OperationManagerFacade.sharedManager

        guard let operation = (networkFacade as? WalletNetworkFacade)?.fetchBalanceOperation([asset.identifier], onlyVisible: false) else {
            return
        }
        operation.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let balance = try? operation.targetOperation.extractResultData(), let balance = balance?.first {
                    self.presenter.didLoadBalance(balance.balance.decimalValue, asset: asset)
                }
            }
        }
        operationManager.enqueue(operations: operation.allOperations, in: .blockAfter)
    }

    struct AssetId: ScaleCodable & Encodable {
        let value: Data

        init(scaleDecoder: ScaleDecoding) throws {
            value = try scaleDecoder.readAndConfirm(count: 32)
        }

        init(value: Data) {
            self.value = value
        }

        func encode(scaleEncoder: ScaleEncoding) throws {
            scaleEncoder.appendRaw(data: value)
        }
    }

    func json(from object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject([object]),
              let data = try? JSONSerialization.data(withJSONObject: [object], options: []) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }

    func subscribePoolXYK(assetId1: String, assetId2: String) {
        guard let engine = polkaswapNetworkFacade?.engine else { return }
        let generation = xykGeneration
        do {
            let storageKey = try StorageKeyFactory()
                .xykPoolKey(asset1: Data.sora(hex: assetId1), asset2: Data.sora(hex: assetId2))
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.xykGeneration == generation else { return }
                    self.presenter?.didUpdatePoolSubscription()
                }
            }

            let failureClosure: (Error, Bool) -> Void = { _, _ in
//                print("XYK failureClosure: \(error)")
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: failureClosure)
            xykPoolSubscriptionIds.append(subscriptionId)
            xykSubscriptions.append((subscriptionId, engine))
        } catch {
//            print("Can't subscribe to storage:  \(error)")
        }
    }

    func subscribePoolTBC(assetId: String) {
        guard let engine = polkaswapNetworkFacade?.engine else { return }
        let generation = tbcGeneration
        do {
            let storageKey = try StorageKeyFactory()
                .tbcPoolKey(asset: Data.sora(hex: assetId))
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.tbcGeneration == generation else { return }
                    self.presenter?.didUpdatePoolSubscription()
                }
            }

            let failureClosure: (Error, Bool) -> Void = { _, _ in
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: failureClosure)
            tbcPoolSubscriptionIds.append(subscriptionId)
            tbcSubscriptions.append((subscriptionId, engine))
        } catch {
//            print("TBC Can't subscribe to storage:  \(error)")
        }
    }

    func unsubscribePoolXYK() {
        xykGeneration = UUID()
        let subscriptions = xykSubscriptions
        xykSubscriptions = []
        xykPoolSubscriptionIds = []
        for subscription in subscriptions {
            subscription.engine.cancelForIdentifier(subscription.id)
        }
    }

    func unsubscribePoolTBC() {
        tbcGeneration = UUID()
        let subscriptions = tbcSubscriptions
        tbcSubscriptions = []
        tbcPoolSubscriptionIds = []
        for subscription in subscriptions {
            subscription.engine.cancelForIdentifier(subscription.id)
        }
    }
}

extension PolkaswapMainInteractor: EventVisitorProtocol {
    func processBalanceChanged(event: WalletBalanceChanged) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter.didUpdateBalance()
        }
    }

    func processNewTransaction(event: WalletNewTransactionInserted) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter.didCreateTransaction()
        }
    }
}
