import Foundation
import SSFUtils
import SSFModels
import RobinHood

protocol PolkaswapOperationFactory {
    func dexInfos() throws -> CompoundOperationWrapper<[String]>
    func accountPools(accountId: Data, baseAssetId: String) throws -> CompoundOperationWrapper<[AccountPool]>
    func poolProperties(baseAssetId: String, targetAssetId: String) -> CompoundOperationWrapper<AccountId?>
    func poolProvidersBalance(reservesId: Data?, accountId: Data) throws -> CompoundOperationWrapper<Decimal>
    func poolTotalIssuances(reservesId: Data?) throws -> CompoundOperationWrapper<Decimal>
    func poolReserves(baseAssetId: String, targetAssetId: String) throws -> CompoundOperationWrapper<PolkaswapPoolReserves?>
    func reservesKeysOperation(baseAssetId: String) throws -> CompoundOperationWrapper<[LiquidityPair]>
}

final class PolkaswapOperationFactoryImpl {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainId: ChainModel.Id
    
    public init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        chainId: ChainModel.Id
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.chainRegistry = chainRegistry
        self.chainId = chainId
    }
}
extension PolkaswapOperationFactoryImpl: PolkaswapOperationFactory {
    func dexInfos() throws -> CompoundOperationWrapper<[String]> {
        guard
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let fetchCoderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        
        let storageOperation: CompoundOperationWrapper<[StorageResponse<DexInfos>]> =
        storageRequestFactory.queryItemsByPrefix(
            engine: engine,
            keys: { [ try StorageKeyFactory().key(from: .dexInfos) ] },
            factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .dexInfos
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(fetchCoderFactoryOperation) }

        let mapOperation = ClosureOperation<[String]> {
            let response = try storageOperation.targetOperation.extractNoCancellableResultData()
            return response.compactMap { $0.value?.baseAssetId.value }
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func accountPools(accountId: Data, baseAssetId: String) throws -> CompoundOperationWrapper<[AccountPool]> {
        guard
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()

        let storageOperation: CompoundOperationWrapper<[StorageResponse<[AssetId]>]> =
        storageRequestFactory.queryItems(
            engine: engine,
            keyParams: {
                [
                    [ NMapKeyParam(value: accountId) ],
                    [ NMapKeyParam(value: AssetId(wrappedValue: baseAssetId)) ]
                ]
            },
            factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .userPools
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(fetchCoderFactoryOperation) }

        let mapOperation = ClosureOperation<[AccountPool]> {
            let result = try storageOperation.targetOperation.extractNoCancellableResultData().first?.value ?? []
            return result.map { AccountPool(poolId: "test", baseAssetId: baseAssetId, targetAssetId: $0.value) }
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func poolProperties(baseAssetId: String, targetAssetId: String) -> CompoundOperationWrapper<AccountId?> {
        print("OLOLO poolProperties \(baseAssetId) \(targetAssetId)")
        guard
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()

        let storageOperation: CompoundOperationWrapper<[StorageResponse<[Data]>]> =
        storageRequestFactory.queryItems(
            engine: engine,
            keyParams: {
                [
                    [ NMapKeyParam(value: AssetId(wrappedValue: baseAssetId)) ],
                    [ NMapKeyParam(value: AssetId(wrappedValue: targetAssetId)) ]
                ]
            },
            factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .poolProperties
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(fetchCoderFactoryOperation) }

        let mapOperation = ClosureOperation<AccountId?> {
            print("OLOLO poolProperties1")
            let storageResponse = try storageOperation.targetOperation.extractNoCancellableResultData().first?.value?.first
            print("OLOLO poolProperties2")
            let decoder = try ScaleDecoder(data: storageResponse ?? Data())
            print("OLOLO poolProperties3")
            let accountId = try AccountId(scaleDecoder: decoder)
            print("OLOLO poolProperties4")
            return accountId
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func poolProvidersBalance(reservesId: Data?, accountId: Data) throws -> CompoundOperationWrapper<Decimal> {
        guard 
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()

        let storageOperation: CompoundOperationWrapper<[StorageResponse<SoraAmountDecimal>]> =
        storageRequestFactory.queryItems(
            engine: engine,
            keyParams: {
                [
                    [ NMapKeyParam(value: reservesId) ],
                    [ NMapKeyParam(value: accountId) ]
                ]
            },
            factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .poolProviders
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(fetchCoderFactoryOperation) }

        let mapOperation = ClosureOperation<Decimal> {
            try storageOperation.targetOperation.extractNoCancellableResultData().first?.value?.decimalValue ?? Decimal(0)
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func poolTotalIssuances(reservesId: Data?) throws -> CompoundOperationWrapper<Decimal> {
        guard
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()

        let storageOperation: CompoundOperationWrapper<[StorageResponse<SoraAmountDecimal>]> =
        storageRequestFactory.queryItems(
            engine: engine,
            keyParams: { [ reservesId ] },
            factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .totalIssuances
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(fetchCoderFactoryOperation) }

        let mapOperation = ClosureOperation<Decimal> {
            try storageOperation.targetOperation.extractNoCancellableResultData().first?.value?.decimalValue ?? Decimal(0)
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func reservesKeysOperation(baseAssetId: String) throws -> CompoundOperationWrapper<[LiquidityPair]> {
        guard
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }
        
        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()
        
        let key = try StorageKeyFactory().xykPoolKeyReserves(asset: Data(hex: baseAssetId))

        let dexInfosWrapper: CompoundOperationWrapper<[StorageResponse<[SoraAmountDecimal]>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: engine,
                keys: { [ key ] },
                factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
                storagePath: .poolReserves
            )

        let mapOperation = ClosureOperation<[LiquidityPair]> {
            let storageResponse = try? dexInfosWrapper.targetOperation.extractNoCancellableResultData()
                
            let reservesInfo = storageResponse?.compactMap { [weak self] response in
                let targetAssetId = response.key.toHex().assetIdFromKey()
                return LiquidityPair(
                    pairId: "\(baseAssetId)-\(targetAssetId)",
                    chainId: self?.chainId,
                    baseAssetId: baseAssetId,
                    targetAssetId: targetAssetId,
                    reserves: response.value?.first?.decimalValue
                )
            }

            return reservesInfo ?? []
        }

        mapOperation.addDependency(dexInfosWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + dexInfosWrapper.allOperations
        )
    }
    
    func poolReserves(baseAssetId: String, targetAssetId: String) throws -> CompoundOperationWrapper<PolkaswapPoolReserves?> {
        guard 
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()

        let storageOperation: CompoundOperationWrapper<[StorageResponse<[SoraAmountDecimal]>]> =
        storageRequestFactory.queryItems(
            engine: engine,
            keyParams: {
                [
                    [ NMapKeyParam(value: AssetId(wrappedValue: baseAssetId)) ],
                    [ NMapKeyParam(value: AssetId(wrappedValue: targetAssetId)) ]
                ]
            },
            factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .poolReserves
        )
        
        storageOperation.allOperations.forEach { $0.addDependency(fetchCoderFactoryOperation) }

        let mapOperation = ClosureOperation<PolkaswapPoolReserves?> {
            let response = try? storageOperation.targetOperation.extractNoCancellableResultData().first?.value ?? []
            return PolkaswapPoolReserves(reserves: response?.first?.decimalValue, fees: response?.last?.decimalValue)
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
}

extension JSONRPCOperation {
    public static func failureOperation(_ error: Error) -> JSONRPCOperation<P, T> {
        let mockEngine = WebSocketEngine(connectionName: nil, url: URL(string: "https://wiki.fearlesswallet.io")!, autoconnect: false)
        let operation = JSONRPCOperation<P, T>(engine: mockEngine, method: "")
        operation.result = .failure(error)
        return operation
    }
}
