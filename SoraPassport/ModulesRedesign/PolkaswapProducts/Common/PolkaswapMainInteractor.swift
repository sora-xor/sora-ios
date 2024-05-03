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
import SSFStorageQueryKit

final class PolkaswapMainInteractor {
    weak var presenter: PolkaswapMainInteractorOutputProtocol!
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let operationManager: OperationManagerProtocol // = OperationManagerFacade.sharedManager
    var eventCenter: EventCenterProtocol

    var xykPoolSubscriptionIds: [UInt16] = []
    var tbcPoolSubscriptionIds: [UInt16] = []

    init(operationManager: OperationManagerProtocol, eventCenter: EventCenterProtocol) {
        self.operationManager = operationManager
        self.eventCenter = eventCenter

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

    func checkIsPathAvailable(fromAssetId: String, toAssetId: String) {
        guard let operation = polkaswapNetworkFacade?.createIsSwapPossibleOperation(dexId: xorDexID,
                                                                                    from: fromAssetId,
                                                                                    to: toAssetId) else {
            return
        }
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let isPathAvailable = try? operation.extractResultData() {
                    self.presenter.didCheckPath(fromAssetId: fromAssetId, toAssetId: toAssetId, isAvailable: isPathAvailable)
                }
            }
        }
        operationManager.enqueue(operations: [operation], in: .blockAfter)
    }

    func loadMarketSources(fromAssetId: String, toAssetId: String) {
        guard let operation = polkaswapNetworkFacade?.createGetAvailableMarketAlgorithmsOperation(dexId: xorDexID,
                                                                                                  from: fromAssetId,
                                                                                                  to: toAssetId) else {
            return
        }
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if let sources = try? operation.extractResultData() {
                    self?.presenter.didLoadMarketSources(sources, fromAssetId: fromAssetId, toAssetId: toAssetId)
                }
            }
        }
        operationManager.enqueue(operations: [operation], in: .blockAfter)
    }

    func quote(params: PolkaswapMainInteractorQuoteParams) {
        let dexs: [UInt32] = [xorDexID, xstusdDexID]
        let operations: [(operation: JSONRPCOperation<[JSONAny], SwapValues>, dexId: UInt32)] = dexs.compactMap { [weak self] dexId in
            guard let networkFacade = self?.polkaswapNetworkFacade else { return nil }
            let operation = networkFacade.createRecalculationOfSwapValuesOperation(
                dexId: dexId,
                from: params.fromAssetId,
                to: params.toAssetId,
                amount: params.amount,
                swapVariant: params.swapVariant,
                liquiditySources: params.liquiditySources,
                filterMode: params.filterMode)
            return (operation, dexId)
        }

        let mergeOperation: BaseOperation<(quote: SwapValues?, dexId: UInt32)> = ClosureOperation {
            let quotes: [(quote: SwapValues?, dexId: UInt32)?] = operations.map { (quote: try? $0.operation.extractResultData(), dexId: $0.dexId) }
            if params.swapVariant == .desiredInput {
                let quote = quotes.compactMap { $0?.quote }.max {
                    (Decimal(string: $0.amount) ?? Decimal(0)) < (Decimal(string: $1.amount) ?? Decimal(0))
                }
                let dexId = quotes.first(where: { $0?.quote == quote })??.dexId ?? 0
                return (quote, dexId)
            }
            
            let quote = quotes.compactMap { $0?.quote }.max {
                (Decimal(string: $0.amount) ?? Decimal(0)) > (Decimal(string: $1.amount) ?? Decimal(0))
            }
            let dexId = quotes.first(where: { $0?.quote == quote })??.dexId ?? 0
            return (quote, dexId)
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
        operationManager.enqueue(operations: [mergeOperation] + operations.map { $0.operation }, in: .blockAfter)
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
                .xykPoolKey(asset1: Data(hex: assetId1), asset2: Data(hex: assetId2))
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
                .tbcPoolKey(asset: Data(hex: assetId))
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
