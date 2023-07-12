import CommonWallet
import FearlessUtils
import RobinHood
import XNetworking

protocol PoolsServiceInputProtocol: AnyObject {
    func subscribePoolsReserves(_ poolsDetails: [PoolInfo])
    func loadPools(isNeedForceUpdate: Bool)
    func updatePools(_ pools: [PoolInfo])
    func getPool(by id: String) -> PoolInfo?
    func getPool(by baseAssetId: String, targetAssetId: String) -> PoolInfo?
    func loadPools(currentAsset: AssetInfo, completion: ([PoolInfo]) -> Void)
    func loadTargetPools(for baseAssetId: String) -> [PoolInfo]
    func appendDelegate(delegate: PoolsServiceOutput)
    
    func isPairEnabled(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void)
    
    func isPairPresentedInNetwork(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void)
}

protocol PoolsServiceOutput: AnyObject {
    func loaded(pools: [PoolInfo])
}

final class PoolsService {
    
    struct PoolsChanges {
        let newOrUpdatedItems: [PoolInfo]
        let removedItems: [PoolInfo]
    }

    var outputs: [PoolsServiceOutput] = []
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let operationManager: OperationManagerProtocol = OperationManager()
    
    var subscriptionIds: [UInt16] = []
    var subscriptionUpdates: [String: String] = [:]
    private var apyInfo: [SbApyInfo] = []
    private let config: ApplicationConfigProtocol
    private let poolRepository: AnyDataProviderRepository<PoolInfo>
    private var currentPools: [PoolInfo] = []
    private var polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol
    
    var currentOrder: [String] {
        get {
            return UserDefaults.standard.array(forKey: "poolsOrder") as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "poolsOrder")
        }
    }
    
    init(
        operationManager: OperationManagerProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        config: ApplicationConfigProtocol
        
    ) {
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.config = config
        
        let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
        self.polkaswapOperationFactory = PolkaswapNetworkOperationFactory(engine: connection!)
        
        self.poolRepository = AnyDataProviderRepository(PoolRepositoryFactory().createRepository())
        
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
                guard let weakSelf = self else { return }
                DispatchQueue.main.asyncDebounce(target: weakSelf, after: 0.25) {
                    self?.loadPools(isNeedForceUpdate: true)
                }
            }
            
            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: { _, _ in })
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
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
                        weakSelf.loadPools(isNeedForceUpdate: true)
                    }
                }
            }
            
            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: { _, _ in })
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

extension PoolsService: PoolsServiceInputProtocol {
    func appendDelegate(delegate: PoolsServiceOutput) {
        outputs.append(delegate)
    }
    
    func getPool(by id: String) -> PoolInfo? {
        return currentPools.first { $0.poolId == id }
    }
    
    func getPool(by baseAssetId: String, targetAssetId: String) -> PoolInfo? {
        if let localPool = currentPools.first(where: { $0.targetAssetId == targetAssetId && $0.baseAssetId == baseAssetId }) {
            return localPool
        }
        
        guard let poolDetails = try? (networkFacade as? WalletNetworkFacade)?.getPoolDetails(baseAsset: baseAssetId,
                                                                                             targetAsset: targetAssetId) else { return nil }
        
        return PoolInfo(baseAssetId: poolDetails.baseAsset,
                        targetAssetId: poolDetails.targetAsset,
                        poolId: "",
                        isFavorite: false,
                        accountId: "",
                        yourPoolShare: poolDetails.yourPoolShare,
                        baseAssetPooledByAccount: poolDetails.baseAssetPooledByAccount,
                        targetAssetPooledByAccount: poolDetails.targetAssetPooledByAccount,
                        baseAssetPooledTotal: poolDetails.baseAssetPooledTotal,
                        targetAssetPooledTotal: poolDetails.targetAssetPooledTotal,
                        totalIssuances: poolDetails.totalIssuances,
                        baseAssetReserves: poolDetails.baseAssetReserves,
                        targetAssetReserves: poolDetails.targetAssetReserves,
                        accountPoolBalance: poolDetails.accountPoolBalance)
    }

    func subscribePoolsReserves(_ poolsDetails: [PoolInfo]) {
        unsubscribePoolsReserves()
        poolsDetails.forEach({
            subscribePoolReserves(baseAsset: $0.baseAssetId, targetAsset: $0.targetAssetId)
        })
    }
    
    func checkIsPairExists(baseAsset: String, targetAsset: String, completion: @escaping (Bool) -> Void) {
        let dexId = polkaswapOperationFactory.dexId(for: baseAsset)
        let operation = polkaswapOperationFactory.isPairEnabled(
            dexId: dexId,
            assetId: baseAsset,
            tokenAddress: targetAsset
        )
        operation.completionBlock = {
            DispatchQueue.main.async {
                let isAvailable = ( try? operation.extractResultData() ) ?? false
                completion(isAvailable)
            }
        }
        operationManager.enqueue(operations: [operation], in: .blockAfter)
    }
    
    func loadPools(currentAsset: AssetInfo, completion: ([PoolInfo]) -> Void) {
        let founded = currentPools.filter { $0.baseAssetId == currentAsset.assetId || $0.targetAssetId == currentAsset.assetId }
        completion(founded)
    }
    
    func loadTargetPools(for baseAssetId: String) -> [PoolInfo] {
        return currentPools.filter { $0.baseAssetId == baseAssetId }
    }
    
    func loadPools(isNeedForceUpdate: Bool) {
        if !currentPools.isEmpty && !isNeedForceUpdate {
            let sortedPools = currentPools.sorted(by: orderSort)
            outputs.forEach {
                $0.loaded(pools: sortedPools)
            }
            return
        }

        guard let fetchRemotePoolsOperation = try? (networkFacade as? WalletNetworkFacade)?.getPoolsDetails() else { return }
        let fetchOperation = poolRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        let processingOperation: BaseOperation<PoolsChanges> = ClosureOperation { [weak self] in
            guard let self = self else { return PoolsChanges(newOrUpdatedItems: [], removedItems: []) }
            let localPools = try fetchOperation.extractNoCancellableResultData()
            let remotePoolDetails = (try? fetchRemotePoolsOperation.targetOperation.extractResultData()) ?? []
            let accountId = (self.networkFacade as? WalletNetworkFacade)?.accountSettings.accountId ?? ""

            let remotePoolInfo = remotePoolDetails.enumerated().map { (index, poolDetail) -> PoolInfo in
                let idData = NSMutableData()
                idData.append(Data(poolDetail.baseAsset.utf8))
                idData.append(Data(poolDetail.targetAsset.utf8))
                idData.append(Data(accountId.utf8))
                let poolId = String(idData.hashValue)
                
                return PoolInfo(baseAssetId: poolDetail.baseAsset,
                                targetAssetId: poolDetail.targetAsset,
                                poolId: poolId,
                                isFavorite: localPools.first { $0.poolId == poolId }?.isFavorite ?? true,
                                accountId: accountId,
                                yourPoolShare: poolDetail.yourPoolShare,
                                baseAssetPooledByAccount: poolDetail.baseAssetPooledByAccount,
                                targetAssetPooledByAccount: poolDetail.targetAssetPooledByAccount,
                                baseAssetPooledTotal: poolDetail.baseAssetPooledTotal,
                                targetAssetPooledTotal: poolDetail.targetAssetPooledTotal,
                                totalIssuances: poolDetail.totalIssuances,
                                baseAssetReserves: poolDetail.baseAssetReserves,
                                targetAssetReserves: poolDetail.targetAssetReserves,
                                accountPoolBalance: poolDetail.accountPoolBalance)
            }.sorted { $0.isFavorite && !$1.isFavorite }
            
            if self.currentOrder.isEmpty {
                self.currentOrder = remotePoolInfo.map { $0.poolId }
            }

            let sortedPools = remotePoolInfo.sorted(by: self.orderSort)
            self.currentPools = sortedPools
            self.outputs.forEach {
                $0.loaded(pools: sortedPools)
            }
            
            let newOrUpdatedItems = remotePoolInfo.filter { !localPools.contains($0) }
            let removedItems = localPools.filter { !remotePoolInfo.contains($0) }
            
            return PoolsChanges(newOrUpdatedItems: newOrUpdatedItems, removedItems: removedItems)
        }

        let localSaveOperation = poolRepository.saveOperation({
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems
        }, {
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.poolId)
        })
        
        processingOperation.addDependency(fetchOperation)
        fetchRemotePoolsOperation.allOperations.forEach { operation in
            processingOperation.addDependency(operation)
        }
        localSaveOperation.addDependency(processingOperation)

        operationManager.enqueue(operations: fetchRemotePoolsOperation.allOperations + [fetchOperation, processingOperation, localSaveOperation], in: .transient)
    }
    
    func updatePools(_ pools: [PoolInfo]) {
        currentOrder = pools.sorted { $0.isFavorite && !$1.isFavorite }.map { $0.poolId }
        
        let pools = pools.map { $0.replacingVisible($0) }
        let localSaveOperation = poolRepository.replaceOperation({
            pools
        })

        currentPools = pools
        operationManager.enqueue(operations: [localSaveOperation], in: .transient)
    }
    
    func isPairEnabled(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void) {
            if currentPools.first(
                where: { $0.accountId == accountId &&
                    $0.baseAssetId == baseAssetId &&
                    $0.targetAssetId == targetAssetId }) != nil {
                completion(true)
                return
            }
            
            let dexId = polkaswapOperationFactory.dexId(for: baseAssetId)
            let operation = polkaswapOperationFactory.isPairEnabled(
                dexId: dexId,
                assetId: baseAssetId,
                tokenAddress: targetAssetId
            )
            operation.completionBlock = {
                DispatchQueue.main.async {
                    let isAvailable = ( try? operation.extractResultData() ) ?? false
                    completion(isAvailable)
                }
            }
            operationManager.enqueue(operations: [operation], in: .blockAfter)
    }
    
    func isPairPresentedInNetwork(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void) {
            if currentPools.first(
                where: { $0.accountId == accountId &&
                    $0.baseAssetId == baseAssetId &&
                    $0.targetAssetId == targetAssetId }) != nil {
                completion(true)
                return
            }
            
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .utility
            
            guard let operation = try? polkaswapOperationFactory.poolReserves(baseAsset: baseAssetId, targetAsset: targetAssetId) else { return }
            operation.completionBlock = {
                DispatchQueue.main.async {
                    let reserves = try? operation.extractResultData()
                    completion(reserves?.underlyingValue != nil)
                }
            }

            operationManager.enqueue(operations: [operation], in: .blockAfter)
        }
}

extension PoolsService {
    private func orderSort(_ asset0: PoolInfo, _ asset1: PoolInfo) -> Bool {
        if let index0 = currentOrder.firstIndex(where: { $0 == asset0.poolId }),
           let index1 = currentOrder.firstIndex(where: { $0 == asset1.poolId }) {
            return index0 < index1
        } else {
            return true
        }
    }
}

