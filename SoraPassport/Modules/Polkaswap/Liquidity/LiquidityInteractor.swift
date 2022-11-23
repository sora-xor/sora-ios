/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CommonWallet
import FearlessUtils
import RobinHood
import BigInt

final class LiquidityInteractor {
    weak var presenter: LiquidityInteractorOutputProtocol?
    let networkFacade: WalletNetworkOperationFactoryProtocol
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    var subscriptionId: UInt16?
    var loadingCounter: Int = 0
    private let feeProvider: FeeProviderProtocol

    init(operationManager: OperationManagerProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
         feeProvider: FeeProviderProtocol) {
        self.operationManager = operationManager
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.feeProvider = feeProvider
    }

    deinit {
        self.unsubscribePoolReserves()
    }
}

extension LiquidityInteractor: LiquidityInteractorInputProtocol {
    var isLoading: Bool {
        loadingCounter > 0
    }

    func networkFeeValue(with type: TransactionType, completion: @escaping (Decimal) -> Void) {
        feeProvider.getFee(for: type) { resultFee in
            completion(resultFee)
        }
    }

    func checkIsPairExists(baseAsset: String, targetAsset: String) {
        loadingCounter += 1
        let dexId = polkaswapNetworkFacade.dexId(for: baseAsset)
        let operation = polkaswapNetworkFacade.isPairEnabled(
            dexId: dexId,
            assetId: baseAsset,
            tokenAddress: targetAsset
        )
        operation.completionBlock = { [weak self] in
            self?.loadingCounter -= 1
            DispatchQueue.main.async {
                let isAvailable = ( try? operation.extractResultData() ) ?? false
                self?.presenter?.didCheckIsPairExists(baseAsset: baseAsset, targetAsset: targetAsset, isExists: isAvailable )
            }
        }
        operationManager.enqueue(operations: [operation], in: .blockAfter)
    }

    func loadBalance(asset: AssetInfo) {
        loadingCounter += 1
        guard let operation = (networkFacade as? WalletNetworkFacade)?.fetchBalanceOperation([asset.identifier], onlyVisible: false) else {
            return
        }
        operation.targetOperation.completionBlock = { [weak self] in
            self?.loadingCounter -= 1
            DispatchQueue.main.async {
                if let balance = try? operation.targetOperation.extractResultData(), let balance = balance?.first {
                    self?.presenter?.didLoadBalance(balance.balance.decimalValue, asset: asset)
                } else {
                    print("Error: no balance for \(asset.identifier)")
                }
            }
        }
        operationManager.enqueue(operations: operation.allOperations, in: .blockAfter)
    }

    func loadPool(baseAsset: String, targetAsset: String) {
        loadingCounter += 1
        let poolDetails = try? (networkFacade as? WalletNetworkFacade)?.getPoolDetails(baseAsset: baseAsset, targetAsset: targetAsset)
        loadingCounter -= 1

        presenter?.didLoadPoolDetails(poolDetails, baseAsset: baseAsset, targetAsset: targetAsset)
    }

    func subscribePoolReserves(asset: String) {
        unsubscribePoolReserves()
        do {
            let storageKey = try StorageKeyFactory()
                .xykPoolKey(asset1: Data(hex: WalletAssetId.xor.rawValue), asset2: Data(hex: asset))
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.presenter?.didUpdatePoolSubscription(asset: asset)
                }
            }

            let failureClosure: (Error, Bool) -> Void = { _, _ in
//                print("XYK failureClosure: \(error)")
            }

            subscriptionId = try polkaswapNetworkFacade.engine.subscribe(RPCMethod.storageSubscribe,
                                                                         params: [[storageKey]],
                                                                         updateClosure: updateClosure,
                                                                         failureClosure: failureClosure)
        } catch {
//            print("Can't subscribe to storage:  \(error)")
        }
    }

    func unsubscribePoolReserves() {
        guard let subscriptionId = subscriptionId else { return }
        polkaswapNetworkFacade.engine.cancelForIdentifier(subscriptionId)
        self.subscriptionId = nil
    }
}
