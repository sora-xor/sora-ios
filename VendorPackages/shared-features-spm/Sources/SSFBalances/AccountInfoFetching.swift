import Foundation
import RobinHood
import SSFAssetManagment
import SSFChainRegistry
import SSFModels
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils

final class AccountInfoFetching: AccountInfoFetchingProtocol {
    private let accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue

    init(
        accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountInfoRepository = accountInfoRepository
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async -> (ChainAsset, AccountInfo?) {
        guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
            chainAsset.storagePath,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
        ) else {
            return (chainAsset, nil)
        }

        let operation = accountInfoRepository.fetchOperation(
            by: localKey,
            options: RepositoryFetchOptions()
        )
        operationQueue.addOperation(operation)

        return await withCheckedContinuation { continuation in
            operation.completionBlock = { [weak self] in
                Task { [weak self] in
                    guard let self else { return }

                    let result = operation.result
                    switch result {
                    case let .success(item):
                        guard let item = item else {
                            continuation.resume(returning: (chainAsset, nil))
                            return
                        }
                        if chainAsset.chain.isEthereum {
                            let result = self.handleEthereumAccountInfo(
                                chainAsset: chainAsset,
                                item: item
                            )
                            continuation.resume(returning: result)
                            return
                        }
                        switch chainAsset.chainAssetType {
                        case .normal:
                            let result = await self.handleAccountInfo(
                                chainAsset: chainAsset,
                                item: item
                            )
                            continuation.resume(returning: result)
                            return
                        case
                            .ormlChain,
                            .ormlAsset,
                            .foreignAsset,
                            .stableAssetPoolToken,
                            .liquidCrowdloan,
                            .vToken,
                            .vsToken,
                            .stable,
                            .assetId,
                            .token2,
                            .xcm:
                            let result = await self.handleOrmlAccountInfo(
                                chainAsset: chainAsset,
                                item: item
                            )
                            continuation.resume(returning: result)
                            return
                        case .equilibrium:
                            let result = await self.handleEquilibrium(
                                chainAsset: chainAsset,
                                accountId: accountId,
                                item: item
                            )
                            continuation.resume(returning: result)
                            return
                        case .assets:
                            let result = await self.handleAssetAccount(
                                chainAsset: chainAsset,
                                item: item
                            )
                            continuation.resume(returning: result)
                            return
                        case .soraAsset:
                            if chainAsset.isUtility {
                                let result = await self.handleAccountInfo(
                                    chainAsset: chainAsset,
                                    item: item
                                )
                                continuation.resume(returning: result)
                                return
                            } else {
                                let result = await self.handleOrmlAccountInfo(
                                    chainAsset: chainAsset,
                                    item: item
                                )
                                continuation.resume(returning: result)
                                return
                            }
                        case .none: break
                        }
                    default:
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }
                }
            }
        }
    }

    func fetch(
        for chainAssets: [ChainAsset],
        accountId: AccountId
    ) async -> [ChainAsset: AccountInfo?] {
        await fetch(
            for: chainAssets,
            accountId: accountId
        )
    }

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        accountId: AccountId
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let accountInfos = await fetch(
            for: chainAssets,
            accountId: accountId
        )
        let mapped: [(ChainAssetKey, AccountInfo?)] = accountInfos
            .compactMap { chainAsset, accountInfo in
                let key = chainAsset.uniqueKey(accountId: accountId)
                return (key, accountInfo)
            }.uniq(predicate: { $0.0 })
        return Dictionary(uniqueKeysWithValues: mapped)
    }

    func fetch(
        for chainAssets: [ChainAsset],
        accountId: AccountId,
        completionBlock _: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) async throws -> [ChainAsset: AccountInfo?] {
        await withCheckedContinuation { continuation in
            let keys = generateStorageKeys(
                for: chainAssets,
                accountId: accountId
            )

            let mapChainAssetsWithKeysOperation = createMapChainAssetsWithKeysOperation(
                chainAssets: chainAssets,
                accountId: accountId
            )

            let fetchOperation = accountInfoRepository.fetchOperation(
                by: keys,
                options: RepositoryFetchOptions()
            )

            let zeroBalanceOperations = createZeroBalanceAccountInfoOperations(
                dependingOn: fetchOperation,
                keys: keys,
                chainAssets: chainAssets,
                accountId: accountId
            )

            zeroBalanceOperations.addDependency(fetchOperation)

            let executeOperation = ClosureOperation { [weak self] in
                Task { [weak self] in
                    let rawResult = try fetchOperation.extractNoCancellableResultData()
                    let chainAssetsByKeys = try mapChainAssetsWithKeysOperation
                        .extractNoCancellableResultData()
                    let zeroOperations = try zeroBalanceOperations.extractNoCancellableResultData()
                    let accountInfoOperations: [ClosureOperation<[ChainAsset: AccountInfo?]>] =
                        await rawResult
                            .asyncCompactMap { [weak self] accountInfoStorageWrapper in
                                await self?.createDecodeOperation(
                                    accountInfoStorageWrapper: accountInfoStorageWrapper,
                                    chainAssetsByKeys: chainAssetsByKeys
                                )
                            } + zeroOperations

                    let accountInfoDependencies = accountInfoOperations
                        .compactMap { $0.dependencies }.reduce(
                            [],
                            +
                        )
                    let accountInfoSubdependencies = accountInfoDependencies
                        .compactMap { $0.dependencies }.reduce(
                            [],
                            +
                        )

                    let finishOperation = ClosureOperation {
                        let accountInfos = accountInfoOperations
                            .compactMap { try? $0.extractNoCancellableResultData() }.flatMap { $0 }
                        let accountInfoByChainAsset = Dictionary(
                            accountInfos,
                            uniquingKeysWith: { _, last in last }
                        )

                        continuation.resume(returning: accountInfoByChainAsset)
                    }

                    accountInfoOperations.forEach { finishOperation.addDependency($0) }
                    accountInfoDependencies.forEach { finishOperation.addDependency($0) }
                    accountInfoSubdependencies.forEach { finishOperation.addDependency($0) }

                    self?.operationQueue.addOperations(
                        [finishOperation] + accountInfoOperations + accountInfoDependencies +
                            accountInfoSubdependencies,
                        waitUntilFinished: false
                    )
                }
            }

            executeOperation.addDependency(mapChainAssetsWithKeysOperation)
            executeOperation.addDependency(fetchOperation)
            executeOperation.addDependency(zeroBalanceOperations)

            operationQueue.addOperations([executeOperation], waitUntilFinished: false)
        }
    }
}

private extension AccountInfoFetching {
    private func createDecodeOperation(
        accountInfoStorageWrapper: AccountInfoStorageWrapper,
        chainAssetsByKeys: [ChainAssetKey: ChainAsset]
    ) async -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        guard let chainAsset = chainAssetsByKeys[accountInfoStorageWrapper.identifier] else {
            return ClosureOperation { [:] }
        }

        if chainAsset.chain.isEthereum {
            return ClosureOperation {
                let accountInfo = try JSONDecoder().decode(
                    AccountInfo?.self,
                    from: accountInfoStorageWrapper.data
                )

                return [chainAsset: accountInfo]
            }
        }

        let chainAssetType = chainAsset.chainAssetType.map { type in
            guard type == .soraAsset else {
                return type
            }

            /* Sora assets logic */
            if chainAsset.isUtility {
                return .normal
            } else {
                return .soraAsset
            }
        }
        switch chainAssetType {
        case .none:
            return ClosureOperation { [chainAsset: nil] }
        case .normal:
            guard let runtimeCodingService = await chainRegistry
                .getRuntimeProvider(for: chainAsset.chain.chainId) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }
            guard let decodingOperation: StorageDecodingOperation<AccountInfo?> =
                createDecodingOperation(
                    for: accountInfoStorageWrapper.data,
                    chainAsset: chainAsset,
                    storagePath: .account,
                    runtimeCodingService: runtimeCodingService
                ) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createNormalMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .soraAsset,
            .assetId,
            .token2,
            .xcm:
            guard let runtimeCodingService = await chainRegistry
                .getRuntimeProvider(for: chainAsset.chain.chainId) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }
            guard let decodingOperation: StorageDecodingOperation<OrmlAccountInfo?> =
                createDecodingOperation(
                    for: accountInfoStorageWrapper.data,
                    chainAsset: chainAsset,
                    storagePath: .tokens,
                    runtimeCodingService: runtimeCodingService
                ) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createOrmlMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        case .equilibrium:
            guard let runtimeCodingService = await chainRegistry
                .getRuntimeProvider(for: chainAsset.chain.chainId) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }
            guard let decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?> =
                createDecodingOperation(
                    for: accountInfoStorageWrapper.data,
                    chainAsset: chainAsset,
                    storagePath: chainAsset.storagePath,
                    runtimeCodingService: runtimeCodingService
                ) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createEquilibriumMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        case .assets:
            guard let runtimeCodingService = await chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ) else {
                return ClosureOperation { [chainAsset: nil] }
            }
            guard let decodingOperation: StorageDecodingOperation<AssetAccount?> =
                createDecodingOperation(
                    for: accountInfoStorageWrapper.data,
                    chainAsset: chainAsset,
                    storagePath: .assetsAccount,
                    runtimeCodingService: runtimeCodingService
                ) else
            {
                return ClosureOperation { [chainAsset: nil] }
            }

            let operation = createAssetMappingOperation(
                chainAsset: chainAsset,
                dependingOn: decodingOperation
            )

            return operation
        }
    }

    private func createZeroBalanceAccountInfoOperations(
        dependingOn fetchOperation: BaseOperation<[AccountInfoStorageWrapper]>,
        keys: [String],
        chainAssets: [ChainAsset],
        accountId: AccountId
    ) -> ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
        let operation = ClosureOperation<[ClosureOperation<[ChainAsset: AccountInfo?]>]> {
            let rawResult = try fetchOperation.extractNoCancellableResultData()
            let zeroBalanceChainAssetKeys = rawResult.compactMap { $0.identifier }.diff(from: keys)
            let zeroBalanceChainAssets = chainAssets.filter { chainAsset in
                guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                    chainAsset.storagePath,
                    chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
                ) else {
                    return false
                }

                return zeroBalanceChainAssetKeys.contains(localKey)
            }

            let zeroBalanceOperations: [ClosureOperation<[ChainAsset: AccountInfo?]>] =
                zeroBalanceChainAssets.compactMap { chainAsset in
                    ClosureOperation { [chainAsset: nil] }
                }

            return zeroBalanceOperations
        }

        return operation
    }

    func createMapChainAssetsWithKeysOperation(
        chainAssets: [ChainAsset],
        accountId: AccountId
    ) -> ClosureOperation<[ChainAssetKey: ChainAsset]> {
        let mapChainAssetsWithKeysOperation = ClosureOperation<[ChainAssetKey: ChainAsset]> {
            let chainAssetsByKeys = chainAssets
                .reduce(into: [ChainAssetKey: ChainAsset]()) { map, chainAsset in
                    guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                        chainAsset.storagePath,
                        chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
                    ) else {
                        return
                    }

                    map[localKey] = chainAsset
                }

            return chainAssetsByKeys
        }

        return mapChainAssetsWithKeysOperation
    }

    func generateStorageKeys(for chainAssets: [ChainAsset], accountId: AccountId) -> [String] {
        let keys: [String] = chainAssets.compactMap { chainAsset in
            guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                chainAsset.storagePath,
                chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
            ) else {
                return nil
            }

            return localKey
        }

        return keys
    }

    func createNormalMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<AccountInfo?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation {
            let accountInfo = try decodingOperation.extractNoCancellableResultData()
            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createOrmlMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<OrmlAccountInfo?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation {
            let ormlAccountInfo = try decodingOperation.extractNoCancellableResultData()
            let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createAssetMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<AssetAccount?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation {
            let assetAccount = try decodingOperation.extractNoCancellableResultData()
            let accountInfo = AccountInfo(assetAccount: assetAccount)
            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createEquilibriumMappingOperation(
        chainAsset: ChainAsset,
        dependingOn decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?>
    ) -> ClosureOperation<[ChainAsset: AccountInfo?]> {
        let operation = ClosureOperation<[ChainAsset: AccountInfo?]> {
            let equilibriumAccountInfo = try decodingOperation.extractNoCancellableResultData()
            var accountInfo: AccountInfo?

            switch equilibriumAccountInfo?.data {
            case let .v0data(info):
                guard let currencyId = chainAsset.asset.tokenProperties?.currencyId else {
                    return [chainAsset: nil]
                }

                let map = info.mapBalances()
                let equilibriumFree = map[currencyId]
                accountInfo = AccountInfo(equilibriumFree: equilibriumFree)
            case .none:
                break
            }

            return [chainAsset: accountInfo]
        }

        operation.addDependency(decodingOperation)

        return operation
    }

    func createDecodingOperation<T: Decodable>(
        for data: Data,
        chainAsset _: ChainAsset,
        storagePath: StorageCodingPath,
        runtimeCodingService: RuntimeProviderProtocol?
    ) -> StorageDecodingOperation<T?>? {
        guard let runtimeCodingService else { return nil }
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<T?>(
            path: storagePath,
            data: data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        return decodingOperation
    }

    func handleOrmlAccountInfo(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) async -> (ChainAsset, AccountInfo?) {
        guard let runtimeCodingService = await chainRegistry
            .getRuntimeProvider(for: chainAsset.chain.chainId) else
        {
            return (chainAsset, nil)
        }
        guard let decodingOperation: StorageDecodingOperation<OrmlAccountInfo?> =
            createDecodingOperation(
                for: item.data,
                chainAsset: chainAsset,
                storagePath: .tokens,
                runtimeCodingService: runtimeCodingService
            ) else
        {
            return (chainAsset, nil)
        }

        operationQueue.addOperations(
            [decodingOperation] + decodingOperation.dependencies,
            waitUntilFinished: false
        )

        return await withCheckedContinuation { continuation in
            decodingOperation.completionBlock = {
                DispatchQueue.main.async {
                    guard let result = decodingOperation.result else {
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }

                    switch result {
                    case let .success(ormlAccountInfo):
                        let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
                        continuation.resume(returning: (chainAsset, accountInfo))
                        return
                    case .failure:
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }
                }
            }
        }
    }

    func handleAccountInfo(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) async -> (ChainAsset, AccountInfo?) {
        guard let runtimeCodingService = await chainRegistry
            .getRuntimeProvider(for: chainAsset.chain.chainId) else
        {
            return (chainAsset, nil)
        }
        guard let decodingOperation: StorageDecodingOperation<AccountInfo?> =
            createDecodingOperation(
                for: item.data,
                chainAsset: chainAsset,
                storagePath: .account,
                runtimeCodingService: runtimeCodingService
            ) else
        {
            return (chainAsset, nil)
        }
        operationQueue.addOperations(
            [decodingOperation] + decodingOperation.dependencies,
            waitUntilFinished: false
        )

        return await withCheckedContinuation { continuation in
            decodingOperation.completionBlock = {
                DispatchQueue.main.async {
                    guard let result = decodingOperation.result else {
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }
                    switch result {
                    case let .success(accountInfo):
                        continuation.resume(returning: (chainAsset, accountInfo))
                        return
                    case .failure:
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }
                }
            }
        }
    }

    private func handleAssetAccount(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) async -> (ChainAsset, AccountInfo?) {
        guard let runtimeCodingService = await chainRegistry
            .getRuntimeProvider(for: chainAsset.chain.chainId) else
        {
            return (chainAsset, nil)
        }
        guard let decodingOperation: StorageDecodingOperation<AssetAccount?> =
            createDecodingOperation(
                for: item.data,
                chainAsset: chainAsset,
                storagePath: .assetsAccount,
                runtimeCodingService: runtimeCodingService
            ) else
        {
            return (chainAsset, nil)
        }

        operationQueue.addOperations(
            [decodingOperation] + decodingOperation.dependencies,
            waitUntilFinished: false
        )

        return await withCheckedContinuation { continuation in
            decodingOperation.completionBlock = {
                DispatchQueue.main.async {
                    guard let result = decodingOperation.result else {
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }

                    switch result {
                    case let .success(assetAccount):
                        let accountInfo = AccountInfo(assetAccount: assetAccount)
                        continuation.resume(returning: (chainAsset, accountInfo))
                    case .failure:
                        continuation.resume(returning: (chainAsset, nil))
                    }
                }
            }
        }
    }

    func handleEquilibrium(
        chainAsset: ChainAsset,
        accountId: AccountId,
        item: AccountInfoStorageWrapper
    ) async -> (ChainAsset, AccountInfo?) {
        guard let runtimeCodingService = await chainRegistry
            .getRuntimeProvider(for: chainAsset.chain.chainId) else
        {
            return (chainAsset, nil)
        }
        guard let decodingOperation: StorageDecodingOperation<EquilibriumAccountInfo?> =
            createDecodingOperation(
                for: item.data,
                chainAsset: chainAsset,
                storagePath: chainAsset.storagePath,
                runtimeCodingService: runtimeCodingService
            ) else
        {
            return (chainAsset, nil)
        }

        operationQueue.addOperations(
            [decodingOperation] + decodingOperation.dependencies,
            waitUntilFinished: false
        )

        return await withCheckedContinuation { continuation in
            decodingOperation.completionBlock = { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    guard let result = decodingOperation.result else {
                        continuation.resume(returning: (chainAsset, nil))
                        return
                    }
                    let accountInfo = self.handleEquilibrium(
                        result: result,
                        chainAsset: chainAsset,
                        accountId: accountId
                    )
                    continuation.resume(returning: accountInfo)
                }
            }
        }
    }

    private func handleEquilibrium(
        result: Swift.Result<EquilibriumAccountInfo?, Error>,
        chainAsset: ChainAsset,
        accountId _: AccountId
    ) -> (ChainAsset, AccountInfo?) {
        switch result {
        case let .success(equilibriumAccountInfo):
            switch equilibriumAccountInfo?.data {
            case let .v0data(info):
                let map = info.mapBalances()
                for chainAsset in chainAsset.chain.chainAssets {
                    guard let currencyId = chainAsset.asset.tokenProperties?.currencyId else {
                        continue
                    }
                    let equilibriumFree = map[currencyId]
                    let accountInfo = AccountInfo(equilibriumFree: equilibriumFree)
                    return (chainAsset, accountInfo)
                }
            case .none:
                return (chainAsset, nil)
            }
        case .failure:
            return (chainAsset, nil)
        }
        return (chainAsset, nil)
    }

    private func handleEthereumAccountInfo(
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) -> (ChainAsset, AccountInfo?) {
        do {
            let accountInfo = try JSONDecoder().decode(AccountInfo?.self, from: item.data)
            return (chainAsset, accountInfo)
        } catch {
            return (chainAsset, nil)
        }
    }
}

extension Array where Element: Hashable {
    func diff(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}
