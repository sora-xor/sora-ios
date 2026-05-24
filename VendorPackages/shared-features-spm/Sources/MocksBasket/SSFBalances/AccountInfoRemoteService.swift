import Foundation
import SSFStorageQueryKit
import SSFChainRegistry
import SSFNetwork
import SSFModels
import SSFUtils
import RobinHood
import SSFAssetManagment
import BigInt

enum AccountInfoRemoteServiceError: Error {
    case requestIdIncorectFormat
}

enum AccountInfoStorageResponseValueRegistry: String {
    case accountInfo = "AccountInfo"
    case orml = "OrmlAccountInfo"
    case equilibrium = "EquilibriumAccountInfo"
    case asset = "AssetAccount"
}

struct AccountInfoStorageRequest: MixStorageRequest {
    typealias Response = AccountInfo
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}

struct OrmlAccountInfoStorageRequest: MixStorageRequest {
    typealias Response = OrmlAccountInfo
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}

struct EquilibriumAccountInfotorageRequest: MixStorageRequest {
    typealias Response = EquilibriumAccountInfo
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}

struct AssetAccountStorageRequest: MixStorageRequest {
    typealias Response = AssetAccount
    let parametersType: MixStorageRequestParametersType
    let storagePath: any StorageCodingPathProtocol
    let requestId: String
}


public protocol AccountInfoRemoteService {
    func fetchAccountInfos(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?]

    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> AccountInfo?
}

public final class AccountInfoRemoteServiceDefault: AccountInfoRemoteService {
    private let runtimeItemRepository: AsyncAnyRepository<RuntimeMetadataItem>
    private let ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching
    private let storagePerformer: StorageRequestPerformer

    public init(
        runtimeItemRepository: AsyncAnyRepository<RuntimeMetadataItem>,
        ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching,
        storagePerformer: StorageRequestPerformer
    ) {
        self.runtimeItemRepository = runtimeItemRepository
        self.ethereumRemoteBalanceFetching = ethereumRemoteBalanceFetching
        self.storagePerformer = storagePerformer
    }

    // MARK: - AccountInfoStorageService

    public func fetchAccountInfos(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?] {
        if chain.isEthereum {
            let accountInfos = try await fetchEthereum(for: chain, accountId: accountId)
            return accountInfos
        } else {
            let accountInfos = try await fetchSubstrate(for: chain, accountId: accountId)
            return accountInfos
        }
    }

    public func fetchAccountInfo(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) async throws -> AccountInfo? {
        if chainAsset.chain.isEthereum {
            let response = try await ethereumRemoteBalanceFetching.fetch(
                for: chainAsset,
                accountId: accountId
            )
            return response.1
        } else {
            let request = createSubstrateRequest(for: chainAsset, accountId: accountId)
            let response = try await storagePerformer.perform([request], chain: chainAsset.chain)
            let map = try createSubstrateMap(from: response, chain: chainAsset.chain)
            let accountInfo = map[chainAsset.chainAssetId] ?? nil
            return accountInfo
        }
    }

    // MARK: - Private substrate methods

    private func fetchSubstrate(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?] {
        let requests = chain.chainAssets.map { createSubstrateRequest(for: $0, accountId: accountId) }
        let result = try await storagePerformer.perform(requests, chain: chain)
        let map = try createSubstrateMap(from: result, chain: chain)
        return map
    }

    private func createSubstrateMap(
        from result: [MixStorageResponse],
        chain: ChainModel
    ) throws -> [ChainAssetId: AccountInfo?] {
        try result.reduce([ChainAssetId: AccountInfo?]()) { part, response in
            guard let assetId = response.request.requestId.split(separator: ":").last else {
                throw AccountInfoRemoteServiceError.requestIdIncorectFormat
            }

            var partial = part
            
            let id = ChainAssetId(chainId: chain.chainId, assetId: String(assetId))
            let accountInfo = try mapAccountInfo(response: response, chain: chain)
            partial[id] = accountInfo

            return partial
        }
    }

    private func mapAccountInfo(response: MixStorageResponse, chain: ChainModel) throws -> AccountInfo? {
        guard let json = response.json else {
            return nil
        }

        guard let registry = AccountInfoStorageResponseValueRegistry(rawValue: response.request.responseTypeRegistry) else {
            throw ConvenienceError(error: "Response type not register")
        }

        var accountInfo: AccountInfo?
        switch registry {
        case .accountInfo:
            accountInfo = try json.map(to: AccountInfo.self)
        case .orml:
            let ormlAccountInfo = try json.map(to: OrmlAccountInfo.self)
            accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
        case .equilibrium:
            let eqAccountInfo = try json.map(to: EquilibriumAccountInfo.self)

            var map: [String: BigUInt] = [:]
            switch eqAccountInfo.data {
            case .v0data(let info):
                map = info.mapBalances()
            }

            let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: response.request.requestId)  // ?? ChainAssetId(id: response.request.requestId)
            guard
                let chainAsset = chain.chainAssets.first(where: { $0.chainAssetId == chainAssetId }),
                let currencyId = chainAsset.asset.tokenProperties?.currencyId
            else {
                return nil
            }

            let balance = map[currencyId]
            accountInfo = AccountInfo(equilibriumFree: balance)
        case .asset:
            let assetAccountInfo = try json.map(to: AssetAccount.self)
            accountInfo = AccountInfo(assetAccount: assetAccountInfo)
        }

        return accountInfo
    }

    private func createSubstrateRequest(for chainAsset: ChainAsset, accountId: AccountId) -> any MixStorageRequest {
        switch chainAsset.currencyId {
        case .soraAsset:
            if chainAsset.isUtility {
                let request = AccountInfoStorageRequest(
                    parametersType: .encodable(param: accountId),
                    storagePath: chainAsset.storagePath,
                    requestId: chainAsset.chainAssetId.id
                )
                return request
            } else {
                let params: [[any SSFStorageQueryKit.NMapKeyParamProtocol]] = [
                    [NMapKeyParam(value: accountId)],
                    [NMapKeyParam(value: chainAsset.currencyId)]
                ]
                let request = OrmlAccountInfoStorageRequest(
                    parametersType: .nMap(params: params),
                    storagePath: chainAsset.storagePath,
                    requestId: chainAsset.chainAssetId.id
                )
                return request
            }
        case .equilibrium:
            let request = EquilibriumAccountInfotorageRequest(
                parametersType: .encodable(param: accountId),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        case .assets:
            let params: [[any SSFStorageQueryKit.NMapKeyParamProtocol]] = [
                [NMapKeyParam(value: chainAsset.currencyId)],
                [NMapKeyParam(value: accountId)]
            ]
            let request = AssetAccountStorageRequest(
                parametersType: .nMap(params: params),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        case .none:
            let parametersType: MixStorageRequestParametersType
            if chainAsset.chain.chainId == Chain.reef.genesisHash || chainAsset.chain.chainId == Chain.scuba.genesisHash {
                parametersType = .encodable(param: accountId.toHexString())
            } else {
                parametersType = .encodable(param: accountId)
            }
            let request = AccountInfoStorageRequest(
                parametersType: parametersType,
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        default:
            let params: [[any SSFStorageQueryKit.NMapKeyParamProtocol]] = [
                [NMapKeyParam(value: accountId)],
                [NMapKeyParam(value: chainAsset.currencyId)]
            ]
            let request = OrmlAccountInfoStorageRequest(
                parametersType: .nMap(params: params),
                storagePath: chainAsset.storagePath,
                requestId: chainAsset.chainAssetId.id
            )
            return request
        }
    }

    // MARK: - Private ethereum methods

    private func fetchEthereum(
        for chain: ChainModel,
        accountId: AccountId
    ) async throws -> [ChainAssetId: AccountInfo?] {
        let chainAsset = chain.chainAssets
        let response = try await ethereumRemoteBalanceFetching.fetch(for: chainAsset, accountId: accountId)
        let mapped = response.map {
            ($0.key.chainAssetId, $0.value)
        }
        let map = Dictionary(uniqueKeysWithValues: mapped)
        return map
    }
}
