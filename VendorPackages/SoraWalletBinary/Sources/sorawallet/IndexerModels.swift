// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
//
// Indexer and config value types the app fills in from PI indexer and config
// responses. They used to come from a prebuilt Kotlin/Native framework
// (sorawallet.xcframework, x-networking). Only these plain data classes were
// still used, so they are Swift source now: same module name, type names,
// initializers and properties, and Kotlin data-class equality.

// The Objective-C framework this replaces re-exported Foundation, and files
// that import sorawallet rely on that.
@_exported import Foundation

/// One parameter of a history item, e.g. `amount` or `assetId`.
public final class TxHistoryItemParam: NSObject {
    public let paramName: String
    public let paramValue: String

    public init(paramName: String, paramValue: String) {
        self.paramName = paramName
        self.paramValue = paramValue
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TxHistoryItemParam else { return false }
        return paramName == other.paramName && paramValue == other.paramValue
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(paramName)
        hasher.combine(paramValue)
        return hasher.finalize()
    }

    override public var description: String {
        "TxHistoryItemParam(paramName=\(paramName), paramValue=\(paramValue))"
    }
}

/// A call nested in a batch or utility extrinsic. A plain Swift class (not an
/// NSObject) so that `hash` can be the call's String hash, as it was in the
/// Kotlin/Native framework.
public final class TxHistoryItemNested: Hashable, CustomStringConvertible {
    public let module: String
    public let method: String
    public let hash: String
    public let data: [TxHistoryItemParam]

    public init(module: String, method: String, hash: String, data: [TxHistoryItemParam]) {
        self.module = module
        self.method = method
        self.hash = hash
        self.data = data
    }

    public static func == (lhs: TxHistoryItemNested, rhs: TxHistoryItemNested) -> Bool {
        lhs.module == rhs.module && lhs.method == rhs.method && lhs.hash == rhs.hash && lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(method)
        hasher.combine(hash)
        hasher.combine(data)
    }

    public var description: String {
        "TxHistoryItemNested(module=\(module), method=\(method), hash=\(hash), data=\(data))"
    }
}

/// One extrinsic in an account's history.
public final class TxHistoryItem: NSObject {
    public let id: String
    public let blockHash: String
    public let module: String
    public let method: String
    public let timestamp: String
    public let networkFee: String
    public let success: Bool
    public let data: [TxHistoryItemParam]?
    public let nestedData: [TxHistoryItemNested]?

    public init(
        id: String,
        blockHash: String,
        module: String,
        method: String,
        timestamp: String,
        networkFee: String,
        success: Bool,
        data: [TxHistoryItemParam]?,
        nestedData: [TxHistoryItemNested]?
    ) {
        self.id = id
        self.blockHash = blockHash
        self.module = module
        self.method = method
        self.timestamp = timestamp
        self.networkFee = networkFee
        self.success = success
        self.data = data
        self.nestedData = nestedData
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TxHistoryItem else { return false }
        return id == other.id && blockHash == other.blockHash && module == other.module &&
            method == other.method && timestamp == other.timestamp && networkFee == other.networkFee &&
            success == other.success && data == other.data && nestedData == other.nestedData
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(blockHash)
        hasher.combine(module)
        hasher.combine(method)
        hasher.combine(timestamp)
        hasher.combine(networkFee)
        hasher.combine(success)
        hasher.combine(data)
        hasher.combine(nestedData)
        return hasher.finalize()
    }

    override public var description: String {
        "TxHistoryItem(id=\(id), blockHash=\(blockHash), module=\(module), method=\(method), " +
            "timestamp=\(timestamp), networkFee=\(networkFee), success=\(success), data=\(String(describing: data)), " +
            "nestedData=\(String(describing: nestedData)))"
    }
}

/// One page of history. `R` documents the item type; items stay untyped as in
/// the Kotlin original, so callers cast them.
public final class TxHistoryResult<R>: NSObject {
    public let endCursor: String?
    public let endReached: Bool
    public let page: Int64
    public let items: [Any]
    public let errorMessage: String?

    public init(endCursor: String?, endReached: Bool, page: Int64, items: [Any], errorMessage: String?) {
        self.endCursor = endCursor
        self.endReached = endReached
        self.page = page
        self.items = items
        self.errorMessage = errorMessage
    }
}

/// A referral reward paid to the referrer.
public final class ReferrerReward: NSObject {
    public let referral: String
    public let amount: String

    public init(referral: String, amount: String) {
        self.referral = referral
        self.amount = amount
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ReferrerReward else { return false }
        return referral == other.referral && amount == other.amount
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(referral)
        hasher.combine(amount)
        return hasher.finalize()
    }

    override public var description: String {
        "ReferrerReward(referral=\(referral), amount=\(amount))"
    }
}

public final class ReferrerRewardsInfo: NSObject {
    public let rewards: [ReferrerReward]

    public init(rewards: [ReferrerReward]) {
        self.rewards = rewards
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ReferrerRewardsInfo else { return false }
        return rewards == other.rewards
    }

    override public var hash: Int {
        rewards.hashValue
    }

    override public var description: String {
        "ReferrerRewardsInfo(rewards=\(rewards))"
    }
}

/// Liquidity and 24-hour price change of a token.
public final class AssetsInfo: NSObject {
    public let tokenId: String
    public let liquidity: String
    public let hourDelta: NSNumber?

    public init(tokenId: String, liquidity: String, hourDelta: NSNumber?) {
        self.tokenId = tokenId
        self.liquidity = liquidity
        self.hourDelta = hourDelta
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AssetsInfo else { return false }
        return tokenId == other.tokenId && liquidity == other.liquidity && hourDelta == other.hourDelta
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(tokenId)
        hasher.combine(liquidity)
        hasher.combine(hourDelta)
        return hasher.finalize()
    }

    override public var description: String {
        "AssetsInfo(tokenId=\(tokenId), liquidity=\(liquidity), hourDelta=\(String(describing: hourDelta)))"
    }
}

public final class SoraConfigNode: NSObject {
    public let chain: String
    public let name: String
    public let address: String

    public init(chain: String, name: String, address: String) {
        self.chain = chain
        self.name = name
        self.address = address
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SoraConfigNode else { return false }
        return chain == other.chain && name == other.name && address == other.address
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(chain)
        hasher.combine(name)
        hasher.combine(address)
        return hasher.finalize()
    }

    override public var description: String {
        "SoraConfigNode(chain=\(chain), name=\(name), address=\(address))"
    }
}

/// Which indexer serves each kind of data.
public final class ConfigExplorerType: NSObject {
    public let fiat: String
    public let reward: String
    public let sbapy: String
    public let assets: String

    public init(fiat: String, reward: String, sbapy: String, assets: String) {
        self.fiat = fiat
        self.reward = reward
        self.sbapy = sbapy
        self.assets = assets
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ConfigExplorerType else { return false }
        return fiat == other.fiat && reward == other.reward && sbapy == other.sbapy && assets == other.assets
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(fiat)
        hasher.combine(reward)
        hasher.combine(sbapy)
        hasher.combine(assets)
        return hasher.finalize()
    }

    override public var description: String {
        "ConfigExplorerType(fiat=\(fiat), reward=\(reward), sbapy=\(sbapy), assets=\(assets))"
    }
}

public final class SoraCurrency: NSObject {
    public let code: String
    public let name: String
    public let sign: String

    public init(code: String, name: String, sign: String) {
        self.code = code
        self.name = name
        self.sign = sign
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SoraCurrency else { return false }
        return code == other.code && name == other.name && sign == other.sign
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(code)
        hasher.combine(name)
        hasher.combine(sign)
        return hasher.finalize()
    }

    override public var description: String {
        "SoraCurrency(code=\(code), name=\(name), sign=\(sign))"
    }
}

/// The mobile config: indexer URL and kinds, nodes, genesis and links.
public final class SoraConfig: NSObject {
    public let remote: Bool
    public let blockExplorerUrl: String
    public let blockExplorerType: ConfigExplorerType
    public let nodes: [SoraConfigNode]
    public let genesis: String
    public let joinUrl: String
    public let substrateTypesUrl: String
    public let soracard: Bool
    public let currencies: [SoraCurrency]

    public init(
        remote: Bool,
        blockExplorerUrl: String,
        blockExplorerType: ConfigExplorerType,
        nodes: [SoraConfigNode],
        genesis: String,
        joinUrl: String,
        substrateTypesUrl: String,
        soracard: Bool,
        currencies: [SoraCurrency]
    ) {
        self.remote = remote
        self.blockExplorerUrl = blockExplorerUrl
        self.blockExplorerType = blockExplorerType
        self.nodes = nodes
        self.genesis = genesis
        self.joinUrl = joinUrl
        self.substrateTypesUrl = substrateTypesUrl
        self.soracard = soracard
        self.currencies = currencies
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SoraConfig else { return false }
        return remote == other.remote && blockExplorerUrl == other.blockExplorerUrl &&
            blockExplorerType == other.blockExplorerType && nodes == other.nodes && genesis == other.genesis &&
            joinUrl == other.joinUrl && substrateTypesUrl == other.substrateTypesUrl &&
            soracard == other.soracard && currencies == other.currencies
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(remote)
        hasher.combine(blockExplorerUrl)
        hasher.combine(blockExplorerType)
        hasher.combine(nodes)
        hasher.combine(genesis)
        hasher.combine(joinUrl)
        hasher.combine(substrateTypesUrl)
        hasher.combine(soracard)
        hasher.combine(currencies)
        return hasher.finalize()
    }

    override public var description: String {
        "SoraConfig(remote=\(remote), blockExplorerUrl=\(blockExplorerUrl), blockExplorerType=\(blockExplorerType), " +
            "nodes=\(nodes), genesis=\(genesis), joinUrl=\(joinUrl), substrateTypesUrl=\(substrateTypesUrl), " +
            "soracard=\(soracard), currencies=\(currencies))"
    }
}
