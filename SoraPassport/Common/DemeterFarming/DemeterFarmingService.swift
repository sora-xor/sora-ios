import Foundation
import IrohaCrypto
import RobinHood
import FearlessUtils

protocol DemeterFarmingServiceProtocol: AnyObject {
    func getFarmedPools(baseAssetId: String?, targetAssetId: String?, completion: @escaping ([StakedPool]) -> Void)
    func getSingleSidedXorFarmedPools(completion: @escaping ([StakedPool]) -> Void)
}

final class DemeterFarmingService {
    private var operationFactory: DemeterFarmingOperationFactory
    private let operationManager = OperationManager()
    private var poolInfos: [StakedPool] = []
    
    init(operationFactory: DemeterFarmingOperationFactory) {
        self.operationFactory = operationFactory
    }
}

extension DemeterFarmingService: DemeterFarmingServiceProtocol {

    func getFarmedPools(baseAssetId: String?, targetAssetId: String?, completion: @escaping ([StakedPool]) -> Void) {
        guard let baseAssetId, let targetAssetId,
              let account = SelectedWalletSettings.shared.currentAccount,
              let accountId = try? SS58AddressFactory().accountId(fromAddress: account.address, type: account.networkType),
              let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let farmedPoolsOperation = try? operationFactory.userInfo(accountId: accountId,
                                                                        runtimeOperation: runtimeService.fetchCoderFactoryOperation()) else {
            return
        }

        farmedPoolsOperation.targetOperation.completionBlock = {
            guard let pools = try? farmedPoolsOperation.targetOperation.extractResultData() else { return }
            let filtredPools = pools.filter { baseAssetId == $0.baseAsset.value && targetAssetId == $0.poolAsset.value && $0.isFarm }
            completion(filtredPools)
        }
        
        operationManager.enqueue(operations: farmedPoolsOperation.allOperations, in: .transient)
    }

    func getSingleSidedXorFarmedPools(completion: @escaping ([StakedPool]) -> Void) {
        guard let account = SelectedWalletSettings.shared.currentAccount,
              let accountId = try? SS58AddressFactory().accountId(fromAddress: account.address, type: account.networkType),
              let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let farmedPoolsOperation = try? operationFactory.userInfo(
                accountId: accountId,
                runtimeOperation: runtimeService.fetchCoderFactoryOperation()
              )
        else {
            return
        }

        farmedPoolsOperation.targetOperation.completionBlock = {
            guard let pools = try? farmedPoolsOperation.targetOperation.extractResultData() else { return }
            let xorId = WalletAssetId.xor.rawValue
            let filtredPools = pools.filter { $0.poolAsset.value == xorId && !$0.isFarm }
            completion(filtredPools)
        }

        operationManager.enqueue(operations: farmedPoolsOperation.allOperations, in: .transient)
    }
}
