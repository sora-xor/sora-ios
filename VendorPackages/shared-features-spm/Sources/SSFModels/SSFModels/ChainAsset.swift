import Foundation
import IrohaCrypto

public typealias ChainAssetKey = String

public struct ChainAsset: Equatable, Hashable {
    public let chain: ChainModel
    public let asset: AssetModel

    public init(chain: ChainModel, asset: AssetModel) {
        self.chain = chain
        self.asset = asset
    }

    public var chainAssetType: SubstrateAssetType? {
        asset.tokenProperties?.type
    }

    public var isUtility: Bool {
        asset.isUtility
    }

    public var isNative: Bool {
        false
    }

    public var currencyId: CurrencyId? {
        switch chainAssetType {
        case .normal:
            if chain.isSora, isUtility {
                guard let currencyId = asset.tokenProperties?.currencyId else {
                    return nil
                }
                return CurrencyId.soraAsset(id: currencyId)
            }
            return nil
        case .ormlChain, .ormlAsset:
            let symbol = asset.tokenProperties?.currencyId ?? asset.symbol
            let tokenSymbol = TokenSymbol(symbol: symbol)
            return CurrencyId.ormlAsset(symbol: tokenSymbol)
        case .foreignAsset:
            guard let foreignAssetId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.foreignAsset(foreignAsset: foreignAssetId)
        case .stableAssetPoolToken:
            guard let stableAssetPoolTokenId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.stableAssetPoolToken(stableAssetPoolToken: stableAssetPoolTokenId)
        case .liquidCrowdloan:
            guard let currencyId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.liquidCrowdloan(liquidCrowdloan: currencyId)
        case .vToken:
            let symbol = asset.tokenProperties?.currencyId ?? asset.symbol
            let tokenSymbol = TokenSymbol(symbol: symbol)
            return CurrencyId.vToken(symbol: tokenSymbol)
        case .vsToken:
            let symbol = asset.tokenProperties?.currencyId ?? asset.symbol
            let tokenSymbol = TokenSymbol(symbol: symbol)
            return CurrencyId.vsToken(symbol: tokenSymbol)
        case .stable:
            let symbol = asset.tokenProperties?.currencyId ?? asset.symbol
            let tokenSymbol = TokenSymbol(symbol: symbol)
            return CurrencyId.stable(symbol: tokenSymbol)
        case .equilibrium:
            guard let currencyId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.equilibrium(id: currencyId)
        case .soraAsset:
            guard let currencyId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.soraAsset(id: currencyId)
        case .assets:
            guard let currencyId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.assets(id: currencyId)
        case .assetId:
            guard let currencyId = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.assetId(id: currencyId)
        case .token2:
            guard let id = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.token2(id: id)
        case .xcm:
            guard let id = asset.tokenProperties?.currencyId else {
                return nil
            }
            return CurrencyId.xcm(id: id)
        case .none:
            return nil
        }
    }

    public func uniqueKey(accountId: AccountId) -> ChainAssetKey {
        let accountIdHex = (accountId as NSData).toHexString()
        return [asset.id, chain.chainId, accountIdHex].joined(separator: ":")
    }

    public func defineEcosystem() -> ChainEcosystem {
        if chain.properties.ethereumBased ?? false {
            return .ethereum
        }
        if chain.parentId == Chain.polkadot.genesisHash || chain.chainId == Chain.polkadot
            .genesisHash
        {
            return .polkadot
        }
        return .kusama
    }
}

public struct ChainAssetId: Equatable, Codable, Hashable {
    public let chainId: ChainModel.Id
    public let assetId: AssetModel.Id

    public init(chainId: ChainModel.Id, assetId: AssetModel.Id) {
        self.chainId = chainId
        self.assetId = assetId
    }

    public var id: String {
        [chainId, assetId].joined(separator: ":")
    }
}

public extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.symbol)
    }

    var rawStakingType: RawStakingType? {
        nil
    }

    var stakingType: StakingType? {
        StakingType(chainAsset: self)
    }

    var debugName: String {
        "\(chain.name)-\(asset.name)"
    }

    var hasStaking: Bool {
        let model: AssetModel? = chain.tokens.tokens?.first { $0.id == asset.id }
        return model?.tokenProperties?.stacking != nil
    }

    var storagePath: StorageCodingPath {
        var storagePath: StorageCodingPath
        switch chainAssetType {
        case .normal, .equilibrium, .none:
            storagePath = StorageCodingPath.account
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
            storagePath = StorageCodingPath.tokens
        case .assets:
            storagePath = StorageCodingPath.assetsAccount
        case .soraAsset:
            if isUtility {
                storagePath = StorageCodingPath.account
            } else {
                storagePath = StorageCodingPath.tokens
            }
        }

        return storagePath
    }
}
