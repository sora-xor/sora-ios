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

    var xykPoolSubscriptionIds: [UInt16] = []
    var tbcPoolSubscriptionIds: [UInt16] = []

    init(
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        dexService: DexInfoService = .shared
    ) {
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.dexService = dexService
    }

    func setup() {
        eventCenter.add(observer: self)
        updateNetworkFeeValue()
    }

    func stop() {
        eventCenter.remove(observer: self)
    }

    fileprivate func updateNetworkFeeValue() {
        //TODO: update networkFeeValue here
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
        let answered = quotes.compactMap { item in item.quote.map { (quote: $0, dexId: item.dexId) } }
        let amount: (SwapValues) -> Decimal = { Decimal(string: $0.amount) ?? Decimal(0) }
        let best: (quote: SwapValues, dexId: UInt32)?
        if swapVariant == .desiredInput {
            best = answered.max { amount($0.quote) < amount($1.quote) }
        } else {
            best = answered.min { amount($0.quote) < amount($1.quote) }
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
        guard let data = try? JSONSerialization.data(withJSONObject: [object], options: []) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }

    func subscribePoolXYK(assetId1: String, assetId2: String) {
        do {
            let storageKey = try StorageKeyFactory()
                .xykPoolKey(asset1: Data.sora(hex: assetId1), asset2: Data.sora(hex: assetId2))
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.presenter.didUpdatePoolSubscription()
                }
            }

            let failureClosure: (Error, Bool) -> Void = { _, _ in
//                print("XYK failureClosure: \(error)")
            }

            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: failureClosure)
            xykPoolSubscriptionIds.append(subscriptionId)
        } catch {
//            print("Can't subscribe to storage:  \(error)")
        }
    }

    func subscribePoolTBC(assetId: String) {
        do {
            let storageKey = try StorageKeyFactory()
                .tbcPoolKey(asset: Data.sora(hex: assetId))
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.presenter.didUpdatePoolSubscription()
                }
            }

            let failureClosure: (Error, Bool) -> Void = { _, _ in
            }

            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: failureClosure)
            tbcPoolSubscriptionIds.append(subscriptionId)
        } catch {
//            print("TBC Can't subscribe to storage:  \(error)")
        }
    }

    func unsubscribePoolXYK() {
        for subscriptionID in xykPoolSubscriptionIds {
            polkaswapNetworkFacade?.engine.cancelForIdentifier(subscriptionID)
        }
        xykPoolSubscriptionIds = []
    }

    func unsubscribePoolTBC() {
        for subscriptionID in tbcPoolSubscriptionIds {
            polkaswapNetworkFacade?.engine.cancelForIdentifier(subscriptionID)
        }
        tbcPoolSubscriptionIds = []
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
