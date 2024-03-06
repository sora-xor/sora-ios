import Foundation
import SSFUtils
import SSFModels
import RobinHood
import IrohaCrypto
import BigInt

enum PolkaswapOperationFactoryError: Error {
    case unexpectedError
}

protocol PolkaswapOperationFactory {
    func dexInfos() throws -> CompoundOperationWrapper<[String]>
    func accountPools(accountId: Data, baseAssetId: String) throws -> CompoundOperationWrapper<[AccountPool]>
    func poolProperties(baseAssetId: String) throws -> CompoundOperationWrapper<[LiquidityPair]>
    func poolProperties(baseAssetId: String, targetAssetId: String) -> CompoundOperationWrapper<AccountId?>
    func poolProvidersBalance(reservesId: Data?, accountId: Data) throws -> CompoundOperationWrapper<BigUInt>
    func poolTotalIssuances(reservesId: Data?) throws -> CompoundOperationWrapper<BigUInt>
    func poolReserves(baseAssetId: String, targetAssetId: String) throws -> CompoundOperationWrapper<PolkaswapPoolReserves?>
    func reservesKeysOperation(baseAssetId: String) throws -> CompoundOperationWrapper<[LiquidityPair]>
}

final class PolkaswapOperationFactoryDefault {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainId: ChainModel.Id
    private let addressFactory: SS58AddressFactoryProtocol
    private let chain: Chain
    
    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        addressFactory: SS58AddressFactoryProtocol,
        chainId: ChainModel.Id,
        chain: Chain
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.chainRegistry = chainRegistry
        self.addressFactory = addressFactory
        self.chainId = chainId
        self.chain = chain
    }
}
extension PolkaswapOperationFactoryDefault: PolkaswapOperationFactory {
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

        let mapOperation = ClosureOperation<[AccountPool]> { [weak self] in
            guard let self else {
                throw PolkaswapOperationFactoryError.unexpectedError
            }
            let result = try storageOperation.targetOperation.extractNoCancellableResultData().first?.value ?? []
            return result.map {
                AccountPool(
                    poolId: "\(baseAssetId)-\($0.value)",
                    accountId: accountId.toHex(),
                    chainId: self.chainId,
                    baseAssetId: baseAssetId,
                    targetAssetId: $0.value
                )
            }
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func poolProperties(baseAssetId: String) throws -> CompoundOperationWrapper<[LiquidityPair]> {
        guard
            let engine = chainRegistry.getConnection(for: chainId),
            let runtimeOperation = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId)
        else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }
        
        let fetchCoderFactoryOperation = runtimeOperation.fetchCoderFactoryOperation()
        
        let key = try StorageKeyFactory().xykPoolKeyProperties(asset: Data(hex: baseAssetId))
        
        let dexInfosWrapper: CompoundOperationWrapper<[StorageResponse<[Data]>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: engine,
                keys: { [ key ] },
                factory: { try fetchCoderFactoryOperation.extractNoCancellableResultData() },
                storagePath: .poolProperties
            )

        let mapOperation = ClosureOperation<[LiquidityPair]> {
            let storageResponse = try dexInfosWrapper.targetOperation.extractNoCancellableResultData()
            
            let pairs = try storageResponse.compactMap { [weak self] response in
                guard let self else {
                    throw PolkaswapOperationFactoryError.unexpectedError
                }

                let targetAssetId = try response.key.toHex().assetIdFromKey()
                let decoder = try ScaleDecoder(data: response.value?.first ?? Data())
                let accountId = try AccountId(scaleDecoder: decoder)
                let reservesId = try self.addressFactory.address(
                    fromAccountId: accountId.value,
                    type: SNAddressType(chain: self.chain)
                )
                return LiquidityPair(
                    pairId: "\(baseAssetId)-\(targetAssetId)",
                    chainId: self.chainId,
                    baseAssetId: baseAssetId,
                    targetAssetId: targetAssetId,
                    reservesId: reservesId
                )
            }
            return pairs
        }

        mapOperation.addDependency(dexInfosWrapper.targetOperation)
        mapOperation.addDependency(fetchCoderFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + dexInfosWrapper.allOperations
        )
    }
    
    func poolProperties(baseAssetId: String, targetAssetId: String) -> CompoundOperationWrapper<AccountId?> {
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
            guard let storageResponse = try storageOperation.targetOperation.extractNoCancellableResultData()
                .first?.value?.first
            else {
                throw PolkaswapOperationFactoryError.unexpectedError
            }
                  
            let decoder = try ScaleDecoder(data: storageResponse)
            let accountId = try AccountId(scaleDecoder: decoder)
            return accountId
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func poolProvidersBalance(reservesId: Data?, accountId: Data) throws -> CompoundOperationWrapper<BigUInt> {
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

        let mapOperation = ClosureOperation<BigUInt> {
            let response = try storageOperation.targetOperation.extractNoCancellableResultData()
            return (response.first?.value?.value) ?? BigUInt(integerLiteral: 0)
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
    
    func poolTotalIssuances(reservesId: Data?) throws -> CompoundOperationWrapper<BigUInt> {
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

        let mapOperation = ClosureOperation<BigUInt> {
            let response = try storageOperation.targetOperation.extractNoCancellableResultData()
            return (response.first?.value?.value) ?? BigUInt(integerLiteral: 0)
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
            let storageResponse = try dexInfosWrapper.targetOperation.extractNoCancellableResultData()
                
            let reservesInfo = try storageResponse.compactMap { [weak self] response in
                let targetAssetId = try response.key.toHex().assetIdFromKey()
                return LiquidityPair(
                    pairId: "\(baseAssetId)-\(targetAssetId)",
                    chainId: self?.chainId,
                    baseAssetId: baseAssetId,
                    targetAssetId: targetAssetId,
                    reserves: response.value?.first?.value
                )
            }

            return reservesInfo
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
            guard let response = try storageOperation.targetOperation.extractNoCancellableResultData().first?.value else {
                throw PolkaswapOperationFactoryError.unexpectedError
            }

            return PolkaswapPoolReserves(
                reserves: response.first?.value ?? BigUInt(integerLiteral: 0),
                fees: response.last?.value ?? BigUInt(integerLiteral: 0)
            )
        }

        mapOperation.addDependency(storageOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchCoderFactoryOperation] + storageOperation.allOperations
        )
    }
}

//TODO: Move it to helpers
extension JSONRPCOperation {
    public static func failureOperation(_ error: Error) -> JSONRPCOperation<P, T> {
        let mockEngine = WebSocketEngine(connectionName: nil, url: URL(string: "https://wiki.fearlesswallet.io")!, autoconnect: false)
        let operation = JSONRPCOperation<P, T>(engine: mockEngine, method: "")
        operation.result = .failure(error)
        return operation
    }
}
