import CommonWallet
import FearlessUtils
import RobinHood
import XNetworking
import IrohaCrypto

protocol ExplorePoolsServiceInputProtocol: AnyObject {
    func getPools() async throws -> [ExplorePool]
}

protocol ExplorePoolsServiceOutput: AnyObject {
}

struct ExplorePool {
    let id: String
    let baseAssetId: String
    let targetAssetId: String
    var tvl: Decimal
    var apy: Decimal?
}

final class ExplorePoolsService {
    
    private let operationManager: OperationManagerProtocol = OperationManager()
    private weak var polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private weak var assetManager: AssetManagerProtocol?
    private weak var fiatService: FiatServiceProtocol?
    private var networkFacade: WalletNetworkOperationFactoryProtocol?
    private var pools: [ExplorePool] = []
    
    init(
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol?,
        polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol?,
        networkFacade: WalletNetworkOperationFactoryProtocol?
    ) {
        self.assetManager = assetManager
        self.fiatService = fiatService
        self.polkaswapOperationFactory = polkaswapOperationFactory
        self.networkFacade = networkFacade
    }
}

extension ExplorePoolsService: ExplorePoolsServiceInputProtocol {
    
    func getPools() async throws -> [ExplorePool] {
        return try await withCheckedThrowingContinuation { continuation in
            if !pools.isEmpty {
                continuation.resume(returning: pools)
                return
            }
                
            let baseAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
            let targetAssetIds: [String] = assetManager?.getAssetList()?.filter { !baseAssetIds.contains($0.assetId) }.map { $0.assetId } ?? []
            var operations: [Operation] = []
            var pools: [ExplorePool] = []
            
            let mapOperation = ClosureOperation<Void> { [weak self] in
                guard let self = self else { return }
                self.pools = pools.sorted(by: { $0.tvl > $1.tvl })
                continuation.resume(returning: self.pools)
            }
            
            for baseAssetId in baseAssetIds {
                for targetAssetId in targetAssetIds {
                    
                    if let operation = try? polkaswapOperationFactory?.poolReserves(baseAsset: baseAssetId, targetAsset: targetAssetId) {
                        operation.completionBlock = { [weak self] in
                            guard let reserves = try? operation.extractResultData()?.underlyingValue?.reserves else { return }
                            let reservesDecimal = Decimal.fromSubstrateAmount(reserves.value, precision: 18) ?? .zero
                            
                            self?.fiatService?.getFiat(completion: { fiatData in
                                let priceUsd = fiatData.first(where: { $0.id == baseAssetId })?.priceUsd?.decimalValue ?? .zero
                                
                                let accountId = (self?.networkFacade as? WalletNetworkFacade)?.accountSettings.accountId ?? ""
                                
                                let idData = NSMutableData()
                                idData.append(Data(baseAssetId.utf8))
                                idData.append(Data(targetAssetId.utf8))
                                idData.append(Data(accountId.utf8))
                                let poolId = String(idData.hashValue)
                                
                                pools.append(ExplorePool(id: poolId,
                                                         baseAssetId: baseAssetId,
                                                         targetAssetId: targetAssetId,
                                                         tvl: priceUsd * reservesDecimal * 2))
                            })
                        }

                        mapOperation.addDependency(operation)
                        operations.append(operation)
                    }
                    
                }
            }

            operationManager.enqueue(operations: operations + [mapOperation], in: .blockAfter)
        }
    }
}
