import CommonWallet
import FearlessUtils
import RobinHood
import XNetworking

final class PolkaswapPoolInteractor {
    weak var presenter: PolkaswapPoolInteractorOutputProtocol!
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let operationManager: OperationManagerProtocol 

    var subscriptionIds: [UInt16] = []
    var subscriptionUpdates: [String: String] = [:]
    private var apyInfo: [SbApyInfo] = []
    private let config: ApplicationConfigProtocol

    init(
        operationManager: OperationManagerProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        config: ApplicationConfigProtocol
    ) {
        self.operationManager = operationManager
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.config = config

        setup()
    }

    func setup() {
        subscribeAccountPools()
    }

    func subscribeAccountPools() {
        subscribeAccountPool(baseAssetId: WalletAssetId.xor.rawValue)
        subscribeAccountPool(baseAssetId: WalletAssetId.xstusd.rawValue)
    }

    func subscribeAccountPool(baseAssetId: String) {
        do {
            guard let accountId = (networkFacade as? WalletNetworkFacade)?.address.accountId,
            let baseAssetIdData = try? Data(hexString: baseAssetId) else { return }
            let storageKey = try StorageKeyFactory()
                .accountPoolsKeyForId(accountId, baseAssetId: baseAssetIdData)
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                DispatchQueue.main.async {
                    self?.presenter.didUpdateAccountPools()
                }
            }

            let failureClosure: (Swift.Error, Bool) -> Void = { _, _ in
//                print("subscribeAccountPools failureClosure: \(error)")
            }

            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: failureClosure)
            subscriptionIds.append(subscriptionId)
        } catch {
//            print("Can't subscribe to storage:  \(error)")
        }
    }

    func subscribePoolReserves(baseAsset: String, targetAsset: String) {
        do {
            let storageKey = try StorageKeyFactory()
                .poolReservesKey(baseAssetId: Data(hex: baseAsset), targetAssetId: Data(hex: targetAsset))
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                guard let weakSelf = self else { return }
                let key = baseAsset + targetAsset
                if weakSelf.subscriptionUpdates[key] == nil {
                    // first call during subscription; ignore
                    weakSelf.subscriptionUpdates[key] = update.params.result.blockHash
                } else {
                    DispatchQueue.main.asyncDebounce(target: weakSelf, after: 0.25) {
                        weakSelf.presenter.didUpdateAccountPoolReserves(baseAsset: baseAsset, targetAsset: targetAsset)
                    }
                }
            }

            let failureClosure: (Swift.Error, Bool) -> Void = { _, _ in
//                print("subscribePoolReserves failureClosure: \(error)")
            }

            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: failureClosure)
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
        }
    }

    func unsubscribePoolsReserves() {
        subscriptionIds.forEach({
            polkaswapNetworkFacade?.engine.cancelForIdentifier($0)
        })
        subscriptionIds = []
        subscriptionUpdates = [:]
    }
}

extension PolkaswapPoolInteractor: PolkaswapPoolInteractorInputProtocol {
    func subscribePoolsReserves(_ poolsDetails: [PoolDetails]) {
        unsubscribePoolsReserves()
        poolsDetails.forEach({
            subscribePoolReserves(baseAsset: $0.baseAsset, targetAsset: $0.targetAsset)
        })
    }

    func loadPools() {
        let operationManager = OperationManagerFacade.sharedManager

        let apyInfoOperation = SubqueryApyInfoOperation<[SbApyInfo]?>(baseUrl: config.subqueryUrl)

        do {
            if let operation = try (networkFacade as? WalletNetworkFacade)?.getPoolsDetails() {
                operation.targetOperation.completionBlock = {
                    if  let apyInfo = try? apyInfoOperation.extractNoCancellableResultData() ?? [],
                        let poolsDetails = try? operation.targetOperation.extractResultData() {
                        let details = poolsDetails.map { detail -> PoolDetails in
                            let apyModel = apyInfo.first { detail.targetAsset == $0.tokenId }
                            let sbAPY = (apyModel?.sbApy as? Double) ?? Double(0)

                            return PoolDetails(baseAsset: detail.baseAsset,
                                               targetAsset: detail.targetAsset,
                                               yourPoolShare: detail.yourPoolShare,
                                               sbAPYL: sbAPY,
                                               baseAssetPooledByAccount: detail.baseAssetPooledByAccount,
                                               targetAssetPooledByAccount: detail.targetAssetPooledByAccount,
                                               baseAssetPooledTotal: detail.baseAssetPooledTotal,
                                               targetAssetPooledTotal: detail.targetAssetPooledTotal,
                                               totalIssuances: detail.totalIssuances,
                                               reserves: detail.reserves)
                        }
                        DispatchQueue.main.async {
                            self.presenter?.didLoadPools(details)
                        }
                    }
                }
                operation.addDependency(operations: [apyInfoOperation])
                operationManager.enqueue(operations: [apyInfoOperation] + operation.allOperations, in: .blockAfter)
            }
        } catch {
            // TODO: show alert
            print(error)
        }
    }
}
