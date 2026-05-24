import Foundation
import RobinHood

public enum ChainBaseType: String {
    case substrate
    case ethereum
}

public enum BlockExplorerType: String, Codable {
    case subquery
    case subsquid
    case giantsquid
    case sora
    case etherscan
    case reef
    case oklink
    case zeta
}

public enum ChainRemoteTokensType: String, Codable {
    case config
    case sora
}

public struct ChainRemoteTokens: Codable, Hashable {
    public let type: ChainRemoteTokensType
    public let whitelist: String?
    public let utilityId: String?
    public let tokens: Set<AssetModel>?

    public init(
        type: ChainRemoteTokensType,
        whitelist: String?,
        utilityId: String?,
        tokens: Set<AssetModel>?
    ) {
        self.type = type
        self.whitelist = whitelist
        self.utilityId = utilityId
        self.tokens = tokens
    }

    public static func == (lhs: ChainRemoteTokens, rhs: ChainRemoteTokens) -> Bool {
        lhs.type == rhs.type &&
            lhs.utilityId == rhs.utilityId &&
            lhs.tokens == rhs.tokens
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tokens)
    }
}

public struct ChainProperties: Codable {
    public let addressPrefix: String
    public let rank: String?
    public let paraId: String?
    public let ethereumBased: Bool?
    public let crowdloans: Bool?

    public init(
        addressPrefix: String,
        rank: String? = nil,
        paraId: String? = nil,
        ethereumBased: Bool? = nil,
        crowdloans: Bool? = nil
    ) {
        self.addressPrefix = addressPrefix
        self.rank = rank
        self.paraId = paraId
        self.ethereumBased = ethereumBased
        self.crowdloans = crowdloans
    }
}

public final class ChainModel: Codable, Identifiable {
    public typealias Id = String

    public let disabled: Bool
    public let chainId: Id
    public let externalApi: ExternalApiSet?
    public var tokens: ChainRemoteTokens

    public var identifier: String { chainId }
    public let rank: UInt16?

    public let parentId: Id?
    public let paraId: String?
    public let name: String

    public let xcm: XcmChain?
    public let nodes: Set<ChainNodeModel>
    public let types: TypesSettings?
    public let icon: URL?
    public let options: [ChainOptions]?

    public var selectedNode: ChainNodeModel?
    public let customNodes: Set<ChainNodeModel>?
    public let iosMinAppVersion: String?
    public let properties: ChainProperties

    public init(
        rank: UInt16?,
        disabled: Bool,
        chainId: Id,
        parentId: Id? = nil,
        paraId: String?,
        name: String,
        tokens: ChainRemoteTokens,
        xcm: XcmChain?,
        nodes: Set<ChainNodeModel>,
        types: TypesSettings? = nil,
        icon: URL?,
        options: [ChainOptions]? = nil,
        externalApi: ExternalApiSet? = nil,
        selectedNode: ChainNodeModel? = nil,
        customNodes: Set<ChainNodeModel>? = nil,
        iosMinAppVersion: String?,
        properties: ChainProperties
    ) {
        self.rank = rank
        self.disabled = disabled
        self.chainId = chainId
        self.parentId = parentId
        self.paraId = paraId
        self.name = name
        self.tokens = tokens
        self.xcm = xcm
        self.nodes = nodes
        self.types = types
        self.icon = icon
        self.options = options
        self.externalApi = externalApi
        self.selectedNode = selectedNode
        self.customNodes = customNodes
        self.iosMinAppVersion = iosMinAppVersion
        self.properties = properties
    }

    public var isRelaychain: Bool {
        parentId == nil
    }

    public var isEthereumBased: Bool {
        options?.contains(.ethereumBased) == true || options?.contains(.ethereum) == true
    }

    public var isEthereum: Bool {
        properties.ethereumBased ?? false
    }

    public var supportsNft: Bool {
        options?.contains(.nft) == true
    }

    public var chainFormat: SFChainFormat {
        if isEthereum {
            return .sfEthereum
        } else {
            return .sfSubstrate(UInt16(properties.addressPrefix) ?? 69)
        }
    }

    public var isTestnet: Bool {
        options?.contains(.testnet) ?? false
    }

    public var isTipRequired: Bool {
        options?.contains(.tipRequired) ?? false
    }

    public var isPolkadot: Bool {
        knownChainEquivalent == .polkadot
    }

    public var isKusama: Bool {
        knownChainEquivalent == .kusama
    }

    public var isPolkadotOrKusama: Bool {
        isPolkadot || isKusama
    }

    public var isWestend: Bool {
        knownChainEquivalent == .westend
    }

    public var isRococo: Bool {
        knownChainEquivalent == .rococo
    }

    public var isSora: Bool {
        name.lowercased() == "sora mainnet" || name.lowercased() == "sora test"
    }

    public var isEquilibrium: Bool {
        knownChainEquivalent == .equilibrium
    }

    public var isTernoa: Bool {
        knownChainEquivalent == .ternoa
    }

    public var isReef: Bool {
        knownChainEquivalent == .reef || knownChainEquivalent == .scuba
    }

    public var isUtilityFeePayment: Bool {
        options?.contains(where: { $0 == .utilityFeePayment }) == true
    }

    public var hasStakingRewardHistory: Bool {
        isPolkadotOrKusama || isWestend
    }

    public var hasCrowdloans: Bool {
        properties.crowdloans ?? false
    }

    public var hasPolkaswap: Bool {
        options?.contains(.polkaswap) == true
    }

    public var chainBaseType: ChainBaseType {
        if isEthereum { return .ethereum }
        return .substrate
    }

    public func utilityAssets() -> Set<AssetModel> {
        tokens.tokens ?? []
    }

    public var erasPerDay: UInt32 {
        let oldChainModel = Chain(rawValue: name)
        switch oldChainModel {
        case .moonbeam: return 4
        case .moonriver, .moonbaseAlpha: return 12
        case .polkadot: return 1
        case .kusama, .westend, .rococo: return 4
        case .soraMain, .soraTest: return 4
        default: return 1 // We have staking only for above chains
        }
    }

    public var emptyURL: URL {
        URL(string: "")!
    }

    public var accountIdLenght: Int {
        isEthereum ? EthereumConstants.accountIdLength : SubstrateConstants.accountIdLength
    }

    public var chainAssets: [ChainAsset] {
        tokens.tokens?.compactMap {
            ChainAsset(chain: self, asset: $0)
        } ?? []
    }

    public var knownChainEquivalent: Chain? {
        Chain(chainId: chainId)
    }

    public var hasXcAssetPrefix: Bool {
        let oldChainModel = Chain(chainId: chainId)
        switch oldChainModel {
        case .moonbeam, .moonriver:
            return true
        default:
            return false
        }
    }

    public func utilityChainAssets() -> [ChainAsset] {
        []
    }

    public func seedSecretTag(metaId: MetaAccountId, accountId: AccountId? = nil) -> String {
        isEthereum
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)
    }

    public func seedTag(metaId: MetaAccountId, accountId: AccountId? = nil) -> String {
        isEthereum
            ? KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)
    }

    public func keystoreTag(metaId: MetaAccountId, accountId: AccountId? = nil) -> String {
        isEthereum
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)
    }

    public func derivationTag(metaId: MetaAccountId, accountId: AccountId? = nil) -> String {
        isEthereum
            ? KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)
    }

    public func replacingSelectedNode(_ node: ChainNodeModel?) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            tokens: tokens,
            xcm: xcm,
            nodes: nodes,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: node,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            properties: properties
        )
    }

    public func replacingCustomNodes(_ newCustomNodes: [ChainNodeModel]) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            tokens: tokens,
            xcm: xcm,
            nodes: nodes,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: Set(newCustomNodes),
            iosMinAppVersion: iosMinAppVersion,
            properties: properties
        )
    }
}

public extension ChainModel {
    func accountRequest(_ accountId: AccountId? = nil) -> ChainAccountRequest {
        ChainAccountRequest(
            chainId: chainId,
            addressPrefix: UInt16(properties.addressPrefix) ?? 69,
            isEthereumBased: isEthereum,
            accountId: accountId
        )
    }
}

extension ChainModel: Hashable, Equatable {
    public static func == (lhs: ChainModel, rhs: ChainModel) -> Bool {
        lhs.rank == rhs.rank
            && lhs.chainId == rhs.chainId
            && lhs.icon == rhs.icon
            && lhs.name == rhs.name
            && lhs.nodes == rhs.nodes
            && lhs.disabled == rhs.disabled
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(chainId)
    }
}

public enum ChainOptions: String, Codable {
    case ethereumBased
    case testnet
    case crowdloans
    case orml
    case tipRequired
    case poolStaking
    case polkaswap
    case ethereum
    case nft
    case utilityFeePayment
    case chainlinkProvider

    case unsupported

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let options = ChainOptions(rawValue: rawValue) {
            self = options
        } else {
            self = .unsupported
        }
    }
}

public extension ChainModel {
    struct TypesSettings: Codable, Hashable {
        public let url: URL
        public let overridesCommon: Bool

        public init(url: URL, overridesCommon: Bool) {
            self.url = url
            self.overridesCommon = overridesCommon
        }
    }

    struct ExternalResource: Codable, Hashable {
        public let type: String
        public let url: URL

        public init(type: String, url: URL) {
            self.type = type
            self.url = url
        }
    }

    struct BlockExplorer: Codable, Hashable {
        public let type: BlockExplorerType
        public let url: URL
        public let apiKey: String?

        public init?(
            type: String,
            url: URL,
            apiKey: String?
        ) {
            guard let externalApiType = BlockExplorerType(rawValue: type) else {
                return nil
            }

            self.type = externalApiType
            self.url = url
            self.apiKey = apiKey
        }
    }

    enum SubscanType: String, Codable, Hashable {
        case extrinsic
        case account
        case event
        case tx
        case address
        case unknown

        public init(from decoder: Decoder) throws {
            self = try SubscanType(
                rawValue: decoder.singleValueContainer().decode(RawValue.self)
            ) ??
                .unknown
        }
    }

    enum ExternalApiExplorerType: String, Codable {
        case subscan
        case polkascan
        case etherscan
        case reef
        case unknown

        public init(from decoder: Decoder) throws {
            self = try ExternalApiExplorerType(
                rawValue: decoder.singleValueContainer().decode(RawValue.self)
            ) ?? .unknown
        }
    }

    struct ExternalApiExplorer: Codable, Hashable {
        public let type: ExternalApiExplorerType
        public let types: [SubscanType]
        public let url: String

        public init(
            type: ChainModel.ExternalApiExplorerType,
            types: [ChainModel.SubscanType],
            url: String
        ) {
            self.type = type
            self.types = types
            self.url = url
        }
    }

    struct ExternalApiSet: Codable, Equatable {
        public let staking: BlockExplorer?
        public let history: BlockExplorer?
        public let crowdloans: ExternalResource?
        public let explorers: [ExternalApiExplorer]?

        public init(
            staking: ChainModel.BlockExplorer? = nil,
            history: ChainModel.BlockExplorer? = nil,
            crowdloans: ChainModel.ExternalResource? = nil,
            explorers: [ChainModel.ExternalApiExplorer]? = nil
        ) {
            self.staking = staking
            self.history = history
            self.crowdloans = crowdloans
            self.explorers = explorers
        }

        public static func == (lhs: ExternalApiSet, rhs: ExternalApiSet) -> Bool {
            lhs.staking == rhs.staking &&
                lhs.history == rhs.history &&
                lhs.crowdloans == rhs.crowdloans &&
                Set(lhs.explorers ?? []) == Set(rhs.explorers ?? [])
        }
    }

    func polkascanAddressURL(_ address: String) -> URL? {
        guard let explorer = externalApi?.explorers?.first(where: { $0.type == .polkascan }) else {
            return nil
        }

        return explorer.explorerUrl(for: address, type: .account)
    }

    func subscanAddressURL(_ address: String) -> URL? {
        guard externalApi?.explorers?.contains(where: { $0.type == .subscan }) == true else {
            return nil
        }

        return URL(string: "https://\(name.lowercased()).subscan.io/account/\(address)")
    }

    func subscanExtrinsicUrl(_ extrinsicHash: String) -> URL? {
        guard externalApi?.explorers?.contains(where: { $0.type == .subscan }) == true else {
            return nil
        }

        return URL(string: "https://\(name.lowercased()).subscan.io/extrinsic/\(extrinsicHash)")
    }

    func etherscanAddressURL(_ address: String) -> URL? {
        guard externalApi?.explorers?.contains(where: { $0.type == .etherscan }) == true else {
            return nil
        }

        return URL(string: "https://etherscan.io/address/\(address)")
    }

    func etherscanTransactionURL(_ hash: String) -> URL? {
        guard externalApi?.explorers?.contains(where: { $0.type == .etherscan }) == true else {
            return nil
        }

        return URL(string: "https://etherscan.io/tx/\(hash)")
    }

    func reefscanAddressURL(_ address: String) -> URL? {
        guard externalApi?.explorers?.contains(where: { $0.type == .reef }) == true else {
            return nil
        }

        return URL(string: "https://reefscan.com/account/\(address)")
    }

    func reefscanTransactionURL(_ hash: String) -> URL? {
        guard externalApi?.explorers?.contains(where: { $0.type == .reef }) == true else {
            return nil
        }

        return URL(string: "https://reefscan.com/extrinsic/\(hash)")
    }
}

public extension ChainModel.ExternalApiExplorer {
    func explorerUrl(for value: String, type: ChainModel.SubscanType) -> URL? {
        let replaceType = url.replacingOccurrences(of: "{type}", with: type.rawValue)
        let replaceValue = replaceType.replacingOccurrences(of: "{value}", with: value)
        return URL(string: replaceValue)
    }

    var transactionType: ChainModel.SubscanType {
        switch type {
        case .etherscan:
            return .tx
        default:
            return .extrinsic
        }
    }
}
