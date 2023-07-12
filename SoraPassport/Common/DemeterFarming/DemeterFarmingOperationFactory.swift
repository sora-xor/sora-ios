import Foundation
import FearlessUtils
import BigInt
import RobinHood

final class DemeterFarmingOperationFactory {
    let engine: JSONRPCEngine
    
    init(engine: JSONRPCEngine) {
        self.engine = engine
    }
    
    func userInfo(accountId: Data,
                  runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>) throws -> CompoundOperationWrapper<[StakedPool]> {
        let parameters = [ try StorageKeyFactory().demeterFarmingUserInfo(identifier: accountId) ]
        
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let eventsWrapper: CompoundOperationWrapper<[StorageResponse<[StakedPool]>]> =
        storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { return try runtimeOperation.extractNoCancellableResultData() },
            storagePath: .demeterFarming
        )
        
        eventsWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }
        
        let mapOperation = ClosureOperation<[StakedPool]> {
            try eventsWrapper.targetOperation.extractNoCancellableResultData().first?.value ?? []
        }

        mapOperation.addDependency(eventsWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [runtimeOperation] + eventsWrapper.allOperations)
    }
}
