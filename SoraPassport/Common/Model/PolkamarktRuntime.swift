// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import CryptoKit
import Foundation
import RobinHood
import SoraKeystore
import SSFUtils

enum PolkamarktRuntimeContract {
    static let sora2NetworkRevision =
        "411dcdb70c5c00b21482a44d02334840d5f338c6"
    static let webContractRevision =
        "893783ba6a19c33043eb5dabe42d949c14d0f257"
    static let webContractCommitTree =
        "e391982c0921dea5278e919a7558b7a6a2afc0d4"
    static let webContractSourceTree =
        "57f0fe7623f2b93b34faecfc66d6c5da96d54e1b"
    static let webContractSourceFileCount = 22
    static let webContractBranch = "ui-updates"
    static let specVersion: UInt32 = 130
    static let transactionVersion: UInt32 = 130
    static let metadataFileSHA256 =
        "2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf"

    /// Canonical identity of the exact metadata object used by the extrinsic
    /// encoder. Keeping this calculation shared prevents an ordinary SORA2
    /// send and a Polkamarkt mutation from applying different runtime gates.
    static func signingMetadataSHA256(
        for factory: RuntimeCoderFactoryProtocol
    ) throws -> String {
        let metadataEncoder = ScaleEncoder()
        try factory.metadata.encode(scaleEncoder: metadataEncoder)
        return rawMetadataSHA256(metadataEncoder.encode())
    }

    static func rawMetadataSHA256(_ metadata: Data) -> String {
        let metadataHex = "0x" + metadata
            .map { String(format: "%02x", $0) }
            .joined()
        return Data(
            SHA256.hash(data: Data((metadataHex + "\n").utf8))
        ).map { String(format: "%02x", $0) }.joined()
    }

    static func wireMetadataSHA256(_ metadataHex: String) -> String? {
        guard
            metadataHex.hasPrefix("0x"),
            metadataHex == metadataHex.lowercased(),
            metadataHex.count > 2,
            metadataHex.count.isMultiple(of: 2),
            metadataHex.dropFirst(2).unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }),
            let metadata = try? Data(hexStringSSF: metadataHex),
            !metadata.isEmpty
        else {
            return nil
        }
        return rawMetadataSHA256(metadata)
    }

    static func matchesReviewedSigningIdentity(
        specVersion: UInt32,
        transactionVersion: UInt32,
        metadataSHA256: String
    ) -> Bool {
        specVersion == Self.specVersion &&
            transactionVersion == Self.transactionVersion &&
            metadataSHA256 == Self.metadataFileSHA256
    }

    /// Accept only the canonical block-zero hash returned by the reviewed
    /// SORA2 mainnet. Runtime versions and metadata are not chain identity: a
    /// custom chain can reuse both, so every authoritative read and signing
    /// preflight must also bind the live RPC connection to block zero.
    static func matchesReviewedGenesisHash(_ value: String) -> Bool {
        guard
            let candidate = PolkamarktTransactionHash.normalized(value),
            value == "0x" + candidate,
            let reviewed = PolkamarktTransactionHash.normalized(
                PIIndexerClient.soraMainnetGenesis
            )
        else {
            return false
        }
        return candidate == reviewed
    }

    static let defaultSlippageBasisPoints: UInt16 = 50
    static let minimumMobileSlippageBasisPoints: UInt16 = 1
    static let maximumMobileSlippageBasisPoints: UInt16 = 1_000
    static let quoteDebounceNanoseconds: UInt64 = 250_000_000
    static let cardHistoryMarketLimit = 12
    static let dpmCurvePointCount = 99
    static let maximumBatchClaims = 24
    static let maximumMarketId = UInt32.max
    static let maximumCloseBlock = UInt32.max
    static let module = "Polkamarkt"
    static let statusFilters = ["active", "finalized", "all"]
    static let openStatuses = ["open", "active", "live"]
    static let finalizedStatuses = [
        "resolved",
        "cancelled",
        "canceled",
        "finalized",
        "closed"
    ]
    static let claimableStatuses = ["resolved", "cancelled", "canceled"]
    enum ClaimConfirmation {
        static let requiresExplicitConfirmation = true
        static let requiredReviewedFields = [
            "accountId",
            "source",
            "marketIds",
            "finalizedBlockHash",
            "claims"
        ]
        static let freshChecksBeforeSigning = [
            "account",
            "featureFlags",
            "runtimeMetadata",
            "claimValues",
            "xorFee",
            "xorBalance"
        ]
        static let title = "Confirm claim"
        static let batchTitle = "Confirm %1$d trader payouts"
        static let body =
            "Verify these finalized runtime values before signing."
        static let feeNotice =
            "The exact XOR network fee and balance will be rechecked before signing."
    }
    static let categories = [
        "Politics",
        "Geopolitics",
        "Elections",
        "Crypto",
        "Macro",
        "Finance",
        "Sports",
        "Technology",
        "AI",
        "Science",
        "Climate",
        "Health",
        "Business",
        "Entertainment",
        "Culture",
        "Legal",
        "Other"
    ]

    enum Call {
        static let buy = "buy"
        static let sell = "sell"
        static let claimMarket = "claim_market"
        static let claimMarkets = "claim_markets"
        static let claimCreatorFees = "claim_creator_fees"

        static let required = [
            buy,
            sell,
            claimMarket,
            claimMarkets,
            claimCreatorFees
        ]
    }

    enum RPC {
        static let quoteBuy = "polkamarkt_quoteBuy"
        static let quoteSell = "polkamarkt_quoteSell"
        static let marketState = "polkamarkt_marketState"
        static let claimable = "polkamarkt_claimable"
    }
}

enum PolkamarktOutcome: String, Codable, CaseIterable {
    case yes = "Yes"
    case no = "No"

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let outcome = Self(rawValue: value) {
            self = outcome
            return
        }

        var container = try decoder.unkeyedContainer()
        let value = try container.decode(String.self)
        guard let outcome = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Polkamarkt outcome \(value)"
            )
        }
        guard
            !container.isAtEnd,
            try container.decodeNil(),
            container.isAtEnd
        else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Malformed Polkamarkt outcome variant"
            )
        }
        self = outcome
    }

    func encode(to encoder: Encoder) throws {
        // DynamicScale's metadata-v14 EnumNode consumes unit variants as
        // [variantName, null], not as a plain Swift raw-value string.
        var container = encoder.unkeyedContainer()
        try container.encode(rawValue)
        try container.encodeNil()
    }
}

enum PolkamarktSide: String, Codable {
    case buy
    case sell
}

enum PolkamarktRuntimeError: LocalizedError {
    case unavailable
    case wrongChain
    case unsupportedRuntime(spec: UInt32, transaction: UInt32)
    case missingCall(String)
    case invalidQuote
    case staleQuote
    case invalidSlippage
    case invalidAmount
    case marketUnavailable
    case mutationsDisabled
    case wrongWalletOrNetwork
    case insufficientKUSD
    case insufficientShares
    case insufficientXOR
    case invalidTransactionHash
    case ambiguousSubmission
    case mutationInFlight
    case pendingRecovery
    case staleClaim

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Polkamarkt is unavailable on the connected SORA2 node."
        case .wrongChain:
            return "The connected node is not the reviewed SORA2 mainnet."
        case let .unsupportedRuntime(spec, transaction):
            return "Unsupported SORA2 runtime \(spec)/\(transaction)."
        case let .missingCall(call):
            return "The connected runtime does not expose Polkamarkt.\(call)."
        case .invalidQuote:
            return "The node returned an invalid Polkamarkt quote."
        case .staleQuote:
            return "The market quote changed beyond the confirmed minimum."
        case .invalidSlippage:
            return "Slippage must be between 0.01% and 10%."
        case .invalidAmount:
            return "The trade amount must be greater than zero."
        case .marketUnavailable:
            return "This market is not currently tradable or claimable."
        case .mutationsDisabled:
            return "Polkamarkt transactions are temporarily disabled."
        case .wrongWalletOrNetwork:
            return "The selected SORA2 wallet changed before signing."
        case .insufficientKUSD:
            return "The KUSD balance is insufficient for this trade."
        case .insufficientShares:
            return "The selected outcome share balance is insufficient."
        case .insufficientXOR:
            return "The XOR balance is insufficient for the network fee."
        case .invalidTransactionHash:
            return "The node or indexer returned an invalid transaction hash."
        case .ambiguousSubmission:
            return "Submission outcome is unknown. The transaction was not retried."
        case .mutationInFlight:
            return "Another wallet transaction is still being prepared."
        case .pendingRecovery:
            return "A previous Polkamarkt transaction must be reconciled first."
        case .staleClaim:
            return "The finalized claim values changed. Review the claim again."
        }
    }
}

enum PolkamarktTransactionHash {
    static func normalized(_ value: String) -> String? {
        let payload: Substring
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            payload = value.dropFirst(2)
        } else {
            payload = value[...]
        }
        guard
            payload.count == 64,
            payload.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (65 ... 70).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }),
            payload.contains(where: { $0 != "0" })
        else {
            return nil
        }
        return payload.lowercased()
    }
}

struct PolkamarktBuyQuote: Codable, Equatable {
    let marketId: UInt32
    let outcome: String
    @StringCodable var collateralIn: BigUInt
    @StringCodable var feeAmount: BigUInt
    @StringCodable var pricingCollateral: BigUInt
    @StringCodable var sharesOut: BigUInt
}

struct PolkamarktSellQuote: Codable, Equatable {
    let marketId: UInt32
    let outcome: String
    @StringCodable var sharesIn: BigUInt
    @StringCodable var grossCollateralOut: BigUInt
    @StringCodable var feeAmount: BigUInt
    @StringCodable var collateralOut: BigUInt
}

struct PolkamarktMarketState: Codable, Equatable {
    let marketId: UInt32
    let mechanism: String
    @StringCodable var virtualDepth: BigUInt
    @StringCodable var realYesShares: BigUInt
    @StringCodable var realNoShares: BigUInt
    @StringCodable var dpmCollateral: BigUInt
    let marginalYesPriceBps: UInt32
    let marginalNoPriceBps: UInt32
    let impliedYesProbabilityBps: UInt32
    let impliedNoProbabilityBps: UInt32
    /// Populated by the mobile coordinator only after reading the market
    /// storage and finalized head used for this state. It is absent from the
    /// raw `polkamarkt_marketState` RPC response.
    var finalizedStatus: PolkamarktMarketStatus? = nil
}

enum PolkamarktMarketStatus: String, Codable, Equatable {
    case open = "Open"
    case locked = "Locked"
    case resolved = "Resolved"
    case cancelled = "Cancelled"

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let status = Self(rawValue: value) {
            self = status
            return
        }
        var container = try decoder.unkeyedContainer()
        let value = try container.decode(String.self)
        guard let status = Self(rawValue: value) else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        guard
            !container.isAtEnd,
            try container.decodeNil(),
            container.isAtEnd
        else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Malformed Polkamarkt status variant"
            )
        }
        self = status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(rawValue)
        try container.encodeNil()
    }
}

private struct PolkamarktStoredMarket: Decodable {
    let status: PolkamarktMarketStatus
    @StringCodable var closeBlock: BigUInt
}

private struct PolkamarktAuthoritativeMarket: Equatable {
    let status: PolkamarktMarketStatus
    let closeBlock: BigUInt
    let observedBlock: BigUInt

    var effectiveStatus: PolkamarktMarketStatus {
        status == .open && observedBlock >= closeBlock ? .locked : status
    }
}

struct PolkamarktClaimable: Codable, Equatable {
    let marketId: UInt32
    let account: String
    let status: String
    let resolutionOutcome: String?
    @StringCodable var yesShares: BigUInt
    @StringCodable var noShares: BigUInt
    @StringCodable var netCollateralPaid: BigUInt
    @StringCodable var traderPayout: BigUInt
    @StringCodable var claimablePayout: BigUInt
    @StringCodable var creatorFees: BigUInt
    let isCreator: Bool
}

struct PolkamarktClaimReview: Equatable {
    let account: String
    let finalizedBlockHash: String
    let claims: [PolkamarktClaimable]
}

enum PolkamarktClaimAuthorizationKind: Equatable {
    case traderPayout
    case creatorFees
}

enum PolkamarktClaimAuthorizationSource: Equatable {
    case selectedDetail
    case reviewedPositions
}

struct PolkamarktClaimAuthorization: Equatable {
    let account: String
    let source: PolkamarktClaimAuthorizationSource
    let reviewedFinalizedBlockHash: String
    let claims: [PolkamarktClaimable]
    let kind: PolkamarktClaimAuthorizationKind

    var marketIds: [UInt32] {
        claims.map(\.marketId)
    }
}

struct PolkamarktMarketReview: Equatable {
    let finalizedBlockHash: String
    let state: PolkamarktMarketState
    let claimable: PolkamarktClaimable?
}

enum PolkamarktClaimValidator {
    static func hasClaimableStatus(
        _ claim: PolkamarktClaimable
    ) -> Bool {
        let normalized = claim.status.lowercased()
        return claim.status ==
            claim.status.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) &&
            PolkamarktRuntimeContract.claimableStatuses
                .contains(normalized)
    }

    static func validated(
        _ claim: PolkamarktClaimable?,
        account: String,
        marketId: UInt32
    ) throws -> PolkamarktClaimable? {
        guard let claim else {
            return nil
        }
        guard
            claim.account == account,
            claim.marketId == marketId
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        return claim
    }

    static func requireTraderPayouts(
        _ claims: [PolkamarktClaimable],
        account: String,
        marketIds: [UInt32]
    ) throws {
        let requested = Set(marketIds)
        let returned = Dictionary(grouping: claims, by: \.marketId)
        guard
            !marketIds.isEmpty,
            requested.count == marketIds.count,
            claims.count == marketIds.count,
            returned.count == requested.count,
            Set(returned.keys) == requested,
            claims.allSatisfy({
                $0.account == account &&
                    hasClaimableStatus($0) &&
                    $0.claimablePayout > 0
            })
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
    }

    static func reviewedClaims(
        _ claims: [PolkamarktClaimable],
        account: String,
        requestedMarketIds: [UInt32]
    ) throws -> [PolkamarktClaimable] {
        let requested = Set(requestedMarketIds)
        let returned = Set(claims.map(\.marketId))
        guard
            !requestedMarketIds.isEmpty,
            requestedMarketIds.count <=
                PolkamarktRuntimeContract.maximumBatchClaims,
            requested.count == requestedMarketIds.count,
            returned.count == claims.count,
            returned.isSubset(of: requested),
            claims.allSatisfy({ $0.account == account })
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        return claims.sorted { $0.marketId < $1.marketId }
    }

    static func requireCreatorFees(
        _ rawClaim: PolkamarktClaimable?,
        account: String,
        marketId: UInt32
    ) throws -> PolkamarktClaimable {
        guard
            let claim = try validated(
                rawClaim,
                account: account,
                marketId: marketId
            ),
            hasClaimableStatus(claim),
            claim.isCreator,
            claim.creatorFees > 0
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        return claim
    }

    static func reviewedTraderAuthorization(
        claims: [PolkamarktClaimable],
        account: String,
        source: PolkamarktClaimAuthorizationSource,
        finalizedBlockHash: String
    ) throws -> PolkamarktClaimAuthorization {
        let sortedClaims = claims.sorted { $0.marketId < $1.marketId }
        let marketIds = sortedClaims.map(\.marketId)
        try requireCanonicalReviewHash(finalizedBlockHash)
        try requireTraderPayouts(
            sortedClaims,
            account: account,
            marketIds: marketIds
        )
        guard
            marketIds == Array(Set(marketIds)).sorted(),
            marketIds.count <= PolkamarktRuntimeContract.maximumBatchClaims,
            (source == .selectedDetail && marketIds.count == 1) ||
                (source == .reviewedPositions && marketIds.count > 1)
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        return PolkamarktClaimAuthorization(
            account: account,
            source: source,
            reviewedFinalizedBlockHash: finalizedBlockHash,
            claims: sortedClaims,
            kind: .traderPayout
        )
    }

    static func reviewedCreatorAuthorization(
        claim: PolkamarktClaimable,
        account: String,
        finalizedBlockHash: String
    ) throws -> PolkamarktClaimAuthorization {
        try requireCanonicalReviewHash(finalizedBlockHash)
        _ = try requireCreatorFees(
            claim,
            account: account,
            marketId: claim.marketId
        )
        return PolkamarktClaimAuthorization(
            account: account,
            source: .selectedDetail,
            reviewedFinalizedBlockHash: finalizedBlockHash,
            claims: [claim],
            kind: .creatorFees
        )
    }

    static func requireFreshAuthorization(
        _ confirmed: PolkamarktClaimAuthorization,
        freshClaims: [PolkamarktClaimable]
    ) throws {
        let refreshed: PolkamarktClaimAuthorization
        do {
            switch confirmed.kind {
            case .traderPayout:
                refreshed = try reviewedTraderAuthorization(
                    claims: freshClaims,
                    account: confirmed.account,
                    source: confirmed.source,
                    finalizedBlockHash: confirmed.reviewedFinalizedBlockHash
                )
            case .creatorFees:
                guard
                    confirmed.source == .selectedDetail,
                    freshClaims.count == 1,
                    let claim = freshClaims.first
                else {
                    throw PolkamarktRuntimeError.staleClaim
                }
                refreshed = try reviewedCreatorAuthorization(
                    claim: claim,
                    account: confirmed.account,
                    finalizedBlockHash: confirmed.reviewedFinalizedBlockHash
                )
            }
        } catch {
            throw PolkamarktRuntimeError.staleClaim
        }
        guard refreshed == confirmed else {
            throw PolkamarktRuntimeError.staleClaim
        }
    }

    private static func requireCanonicalReviewHash(
        _ value: String
    ) throws {
        guard
            let normalized = PolkamarktTransactionHash.normalized(value),
            value == "0x" + normalized
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
    }
}

struct PolkamarktQuoteConfirmation: Equatable {
    let finalizedBlockHash: String
    let marketStatus: PolkamarktMarketStatus
    let closeBlock: BigUInt
    let side: PolkamarktSide
    let input: BigUInt
    let output: BigUInt
    let marketFee: BigUInt
    let networkFee: BigUInt
    let minimumOutput: BigUInt
    let inputBalance: BigUInt
    let xorBalance: BigUInt
}

struct PolkamarktTradeRequest: Equatable {
    let account: String
    let marketId: UInt32
    let outcome: PolkamarktOutcome
    let side: PolkamarktSide
    let input: BigUInt
    let minimumOutput: BigUInt
    let confirmedCloseBlock: BigUInt
    let confirmedMarketFee: BigUInt
    let maximumNetworkFee: BigUInt
}

struct PolkamarktBuyCall: Codable {
    let marketId: UInt32
    let outcome: PolkamarktOutcome
    @StringCodable var collateralIn: BigUInt
    @StringCodable var minSharesOut: BigUInt

    enum CodingKeys: String, CodingKey {
        case marketId = "market_id"
        case outcome
        case collateralIn = "collateral_in"
        case minSharesOut = "min_shares_out"
    }
}

struct PolkamarktSellCall: Codable {
    let marketId: UInt32
    let outcome: PolkamarktOutcome
    @StringCodable var sharesIn: BigUInt
    @StringCodable var minCollateralOut: BigUInt

    enum CodingKeys: String, CodingKey {
        case marketId = "market_id"
        case outcome
        case sharesIn = "shares_in"
        case minCollateralOut = "min_collateral_out"
    }
}

struct PolkamarktMarketCall: Codable {
    let marketId: UInt32

    enum CodingKeys: String, CodingKey {
        case marketId = "market_id"
    }
}

struct PolkamarktBatchClaimCall: Codable {
    let marketIds: [UInt32]

    enum CodingKeys: String, CodingKey {
        case marketIds = "market_ids"
    }
}

extension RuntimeCall where T == PolkamarktBuyCall {
    static func polkamarktBuy(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(
            moduleName: PolkamarktRuntimeContract.module,
            callName: PolkamarktRuntimeContract.Call.buy,
            args: args
        )
    }
}

extension RuntimeCall where T == PolkamarktSellCall {
    static func polkamarktSell(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(
            moduleName: PolkamarktRuntimeContract.module,
            callName: PolkamarktRuntimeContract.Call.sell,
            args: args
        )
    }
}

extension RuntimeCall where T == PolkamarktMarketCall {
    static func polkamarktClaim(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(
            moduleName: PolkamarktRuntimeContract.module,
            callName: PolkamarktRuntimeContract.Call.claimMarket,
            args: args
        )
    }

    static func polkamarktClaimCreatorFees(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(
            moduleName: PolkamarktRuntimeContract.module,
            callName: PolkamarktRuntimeContract.Call.claimCreatorFees,
            args: args
        )
    }
}

extension RuntimeCall where T == PolkamarktBatchClaimCall {
    static func polkamarktBatchClaim(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(
            moduleName: PolkamarktRuntimeContract.module,
            callName: PolkamarktRuntimeContract.Call.claimMarkets,
            args: args
        )
    }
}

private final class PolkamarktRPCOperationRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var operation: Operation?
    private var isCancelled = false

    func set(_ operation: Operation) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            operation.cancel()
            return
        }
        self.operation = operation
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let operation = operation
        self.operation = nil
        lock.unlock()
        operation?.cancel()
    }
}

final class PolkamarktRPCClient {
    private static let requestTimeoutSeconds = 30
    private let engine: JSONRPCEngine

    init(engine: JSONRPCEngine) {
        self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)
    }

    func finalizedHead() async throws -> String {
        try await call(RPCMethod.getHead, parameters: Optional<[String]>.none)
    }

    func reviewedGenesisHash() async throws -> String {
        let maybeHash: String? = try await call(
            RPCMethod.getBlockHash,
            parameters: [0]
        )
        guard
            let hash = maybeHash,
            PolkamarktRuntimeContract.matchesReviewedGenesisHash(hash)
        else {
            throw PolkamarktRuntimeError.wrongChain
        }
        return hash
    }

    func header(at blockHash: String) async throws -> Block.Header {
        try await call(
            RPCMethod.getHeader,
            parameters: [blockHash]
        )
    }

    func metadataHex() async throws -> String {
        try await call(
            RPCMethod.getRuntimeMetadata,
            parameters: Optional<[String]>.none
        )
    }

    func finalizedBlockNumber() async throws -> BigUInt {
        let hash = try await finalizedHead()
        let finalizedHeader = try await header(at: hash)
        guard let number = Self.blockNumber(finalizedHeader.number) else {
            throw PolkamarktRuntimeError.unavailable
        }
        return number
    }

    func canonicalExtrinsicHashes(
        at blockNumber: Int,
        notAfter finalizedBlockNumber: BigUInt
    ) async throws -> (
        blockHash: String,
        extrinsicIndices: [String: UInt32]
    )? {
        guard
            blockNumber >= 0,
            BigUInt(blockNumber) <= finalizedBlockNumber
        else {
            return nil
        }
        let maybeHash: String? = try await call(
            RPCMethod.getBlockHash,
            parameters: [blockNumber]
        )
        guard
            let blockHash = maybeHash,
            let normalizedBlockHash = PolkamarktTransactionHash.normalized(
                blockHash
            )
        else {
            return nil
        }
        let signedBlock: SignedBlock = try await call(
            RPCMethod.getChainBlock,
            parameters: [blockHash]
        )
        guard
            Self.blockNumber(signedBlock.block.header.number) ==
                BigUInt(blockNumber)
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        var indices: [String: UInt32] = [:]
        for (index, encodedExtrinsic) in signedBlock.block.extrinsics.enumerated() {
            guard let extrinsicIndex = UInt32(exactly: index) else {
                throw PolkamarktRuntimeError.unavailable
            }
            let bytes = try Data(hexStringSSF: encodedExtrinsic)
            let digest = try bytes.blake2b32().toHex(includePrefix: false)
            guard let normalized = PolkamarktTransactionHash.normalized(digest)
            else {
                throw PolkamarktRuntimeError.invalidTransactionHash
            }
            guard indices.updateValue(
                extrinsicIndex,
                forKey: normalized
            ) == nil else {
                throw PolkamarktRuntimeError.unavailable
            }
        }
        return (normalizedBlockHash, indices)
    }

    func quoteBuy(
        marketId: UInt32,
        outcome: PolkamarktOutcome,
        collateralIn: BigUInt,
        at blockHash: String
    ) async throws -> PolkamarktBuyQuote? {
        try await call(
            PolkamarktRuntimeContract.RPC.quoteBuy,
            parameters: [
                JSONAny(marketId),
                JSONAny(outcome.rawValue),
                JSONAny(collateralIn.description),
                JSONAny(blockHash)
            ]
        )
    }

    func quoteSell(
        marketId: UInt32,
        outcome: PolkamarktOutcome,
        sharesIn: BigUInt,
        at blockHash: String
    ) async throws -> PolkamarktSellQuote? {
        try await call(
            PolkamarktRuntimeContract.RPC.quoteSell,
            parameters: [
                JSONAny(marketId),
                JSONAny(outcome.rawValue),
                JSONAny(sharesIn.description),
                JSONAny(blockHash)
            ]
        )
    }

    func marketState(
        marketId: UInt32,
        at blockHash: String
    ) async throws -> PolkamarktMarketState? {
        try await call(
            PolkamarktRuntimeContract.RPC.marketState,
            parameters: [JSONAny(marketId), JSONAny(blockHash)]
        )
    }

    func claimable(
        account: String,
        marketId: UInt32,
        at blockHash: String
    ) async throws -> PolkamarktClaimable? {
        try await call(
            PolkamarktRuntimeContract.RPC.claimable,
            parameters: [
                JSONAny(account),
                JSONAny(marketId),
                JSONAny(blockHash)
            ]
        )
    }

    func freeBalance(
        account: String,
        assetId: String,
        at blockHash: String
    ) async throws -> BigUInt {
        let balance: BalanceInfo? = try await call(
            RPCMethod.freeBalance,
            parameters: [
                JSONAny(account),
                JSONAny(assetId),
                JSONAny(blockHash)
            ]
        )
        return balance?.balance ?? 0
    }

    private func call<Parameters: Codable, Response: Decodable>(
        _ method: String,
        parameters: Parameters?
    ) async throws -> Response {
        let operation = JSONRPCOperation<Parameters, Response>(
            engine: engine,
            method: method,
            parameters: parameters,
            timeout: Self.requestTimeoutSeconds
        )
        let relay = PolkamarktRPCOperationRelay()
        return try await withTaskCancellationHandler(
            operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation {
                    continuation in
                    operation.completionBlock = { [weak operation] in
                        guard let operation else {
                            continuation.resume(
                                throwing: PolkamarktRuntimeError.unavailable
                            )
                            return
                        }
                        do {
                            continuation.resume(
                                returning: try operation
                                    .extractNoCancellableResultData()
                            )
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    relay.set(operation)
                    OperationManagerFacade.sharedDefaultQueue.addOperation(
                        operation
                    )
                }
            },
            onCancel: {
                relay.cancel()
            }
        )
    }

    private static func blockNumber(_ value: String) -> BigUInt? {
        let payload: Substring
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            payload = value.dropFirst(2)
        } else {
            return nil
        }
        guard
            !payload.isEmpty,
            payload.count <= 64,
            payload.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (65 ... 70).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            })
        else {
            return nil
        }
        return BigUInt(String(payload), radix: 16)
    }
}

final class PolkamarktRuntimeValidator {
    private let runtimeService: RuntimeCodingServiceProtocol
    private let rpc: PolkamarktRPCClient

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        rpc: PolkamarktRPCClient
    ) {
        self.runtimeService = runtimeService
        self.rpc = rpc
    }

    func validate() async throws -> RuntimeCoderFactoryProtocol {
        // Chain identity is independent of runtime versions and metadata.
        // Read it from this exact live engine before accepting either
        // authoritative state or a factory that may later encode a mutation.
        _ = try await rpc.reviewedGenesisHash()
        let factory = try await fetchFactory()
        try validateSigningFactory(factory)
        let metadataHex = try await rpc.metadataHex()
        guard
            PolkamarktRuntimeContract.wireMetadataSHA256(metadataHex) ==
                PolkamarktRuntimeContract.metadataFileSHA256
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        return factory
    }

    func validateSigningFactory(
        _ factory: RuntimeCoderFactoryProtocol
    ) throws {
        guard
            factory.specVersion == PolkamarktRuntimeContract.specVersion,
            factory.txVersion == PolkamarktRuntimeContract.transactionVersion
        else {
            throw PolkamarktRuntimeError.unsupportedRuntime(
                spec: factory.specVersion,
                transaction: factory.txVersion
            )
        }
        // The factory supplies the metadata that resolves pallet/call indices and
        // SCALE-encodes the signed call. Bind that exact object to the reviewed
        // runtime-130 metadata bytes; matching versions and call names alone are
        // insufficient because a different metadata layout can reuse both.
        let metadataSHA256 = try PolkamarktRuntimeContract
            .signingMetadataSHA256(for: factory)
        guard PolkamarktRuntimeContract.matchesReviewedSigningIdentity(
            specVersion: factory.specVersion,
            transactionVersion: factory.txVersion,
            metadataSHA256: metadataSHA256
        ) else {
            throw PolkamarktRuntimeError.unavailable
        }
        for call in PolkamarktRuntimeContract.Call.required {
            guard try factory.metadata.getFunction(
                from: PolkamarktRuntimeContract.module,
                with: call
            ) != nil else {
                throw PolkamarktRuntimeError.missingCall(call)
            }
        }
    }

    private func fetchFactory() async throws -> RuntimeCoderFactoryProtocol {
        let operation = runtimeService.fetchCoderFactoryOperation(with: 30)
        let relay = PolkamarktRPCOperationRelay()
        return try await withTaskCancellationHandler(
            operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation {
                    continuation in
                    operation.completionBlock = { [weak operation] in
                        guard let operation else {
                            continuation.resume(
                                throwing: PolkamarktRuntimeError.unavailable
                            )
                            return
                        }
                        do {
                            continuation.resume(
                                returning: try operation
                                    .extractNoCancellableResultData()
                            )
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    relay.set(operation)
                    OperationManagerFacade.sharedDefaultQueue.addOperation(
                        operation
                    )
                }
            },
            onCancel: {
                relay.cancel()
            }
        )
    }
}

enum PolkamarktQuoteValidator {
    static let basisPoints: BigUInt = 10_000

    /// Runtime API quote projections are part of the signed Polkamarkt
    /// contract. Accepting alternate casing would let two platform clients
    /// bind different textual projections to the same SCALE outcome.
    static func validateOutcome(
        _ rawOutcome: String,
        expected: PolkamarktOutcome
    ) throws {
        guard rawOutcome == expected.rawValue else {
            throw PolkamarktRuntimeError.invalidQuote
        }
    }

    static func minimumOutput(
        quoteOutput: BigUInt,
        slippageBasisPoints: UInt16
    ) throws -> BigUInt {
        guard (
            PolkamarktRuntimeContract.minimumMobileSlippageBasisPoints ...
                PolkamarktRuntimeContract.maximumMobileSlippageBasisPoints
        ).contains(slippageBasisPoints) else {
            throw PolkamarktRuntimeError.invalidSlippage
        }
        return quoteOutput *
            (basisPoints - BigUInt(slippageBasisPoints)) /
            basisPoints
    }

    static func validate(
        refreshedOutput: BigUInt,
        confirmedMinimum: BigUInt
    ) throws {
        guard refreshedOutput >= confirmedMinimum else {
            throw PolkamarktRuntimeError.staleQuote
        }
    }
}

enum PolkamarktExactFeeValidator {
    static func validate(
        rawFee: String,
        maximumNetworkFee: BigUInt?
    ) throws -> BigUInt {
        guard let fee = BigUInt(rawFee), fee > 0 else {
            throw PolkamarktRuntimeError.invalidQuote
        }
        if let maximumNetworkFee {
            guard maximumNetworkFee > 0, fee <= maximumNetworkFee else {
                throw PolkamarktRuntimeError.staleQuote
            }
        }
        return fee
    }
}

enum PolkamarktSigningHeadValidator {
    static func validate(expected: String, actual: String) throws {
        guard
            let expected = PolkamarktTransactionHash.normalized(expected),
            let actual = PolkamarktTransactionHash.normalized(actual),
            expected == actual
        else {
            throw PolkamarktRuntimeError.staleQuote
        }
    }
}

/// KUSD, XOR and outcome-share input remains integer based all the way to
/// SCALE encoding. This codec is only a presentation boundary; it never
/// converts through Double or Decimal.
enum PolkamarktAmountCodec {
    static let precision = 18
    private static let maximumInputBytes = 4_096
    private static let base = BigUInt(10).power(precision)

    static func parse(_ value: String) throws -> BigUInt {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !normalized.isEmpty,
            normalized.utf8.count <= maximumInputBytes,
            normalized.range(
                of: #"^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$"#,
                options: .regularExpression
            ) != nil
        else {
            throw PolkamarktRuntimeError.invalidAmount
        }
        let parts = normalized.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard
            fraction.count <= precision,
            let whole = BigUInt(parts[0])
        else {
            throw PolkamarktRuntimeError.invalidAmount
        }
        let paddedFraction = fraction.padding(
            toLength: precision,
            withPad: "0",
            startingAt: 0
        )
        guard let fractional = BigUInt(paddedFraction) else {
            throw PolkamarktRuntimeError.invalidAmount
        }
        let result = whole * base + fractional
        guard result > 0 else {
            throw PolkamarktRuntimeError.invalidAmount
        }
        return result
    }

    static func format(_ value: BigUInt, maximumFractionDigits: Int = 6) -> String {
        let whole = value / base
        guard maximumFractionDigits > 0 else {
            return whole.description
        }
        var fraction = (value % base).description
        if fraction.count < precision {
            fraction = String(repeating: "0", count: precision - fraction.count) + fraction
        }
        fraction = String(fraction.prefix(min(maximumFractionDigits, precision)))
        while fraction.last == "0" {
            fraction.removeLast()
        }
        return fraction.isEmpty
            ? whole.description
            : "\(whole).\(fraction)"
    }
}

enum PolkamarktPendingState: String, Codable {
    case preparing
    /// The exact signed hash is durable, but the retained SORA2 transport
    /// witness has not yet crossed its final pre-handoff barrier.
    case signedBeforeTransport
    case failedBeforeSubmission
    case submitting
    case submissionUnknown
    case submitted
    case finalized
    case rejected

    var isTerminal: Bool {
        self == .failedBeforeSubmission || self == .finalized || self == .rejected
    }
}

struct PolkamarktPendingMutation: Codable, Equatable, Identifiable {
    let id: UUID
    let account: String
    let action: String
    let marketIds: [UInt32]
    let createdAt: Date
    var updatedAt: Date
    var extrinsicHash: String?
    var state: PolkamarktPendingState
    var finalizedBlock: Int?
    var errorClass: String?

    var identifier: String {
        id.uuidString
    }
}

struct PolkamarktPendingResolution: Equatable {
    let finalizedBlock: Int
    let succeeded: Bool
}

enum PolkamarktPreTransportRecoveryDecision: Equatable {
    case failedBeforeSubmission(errorClass: String)
    case submissionUnknown(errorClass: String)
    case submitted
}

enum PolkamarktPreTransportRecoveryPolicy {
    /// Classifies only the new phase-coupled journal state. Legacy
    /// `.submitting` records remain ambiguous even if the SORA2 journal no
    /// longer contains their hash because older submitted entries were
    /// prunable.
    static func decision(
        for mutation: PolkamarktPendingMutation,
        sora2Witness: Sora2PendingSubmission?
    ) throws -> PolkamarktPreTransportRecoveryDecision {
        guard
            mutation.state == .signedBeforeTransport,
            let rawHash = mutation.extrinsicHash,
            let hash = PolkamarktTransactionHash.normalized(rawHash)
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        guard let sora2Witness else {
            // For this new state, absence is proof: staging starts with a new
            // non-prunable enum value, transport admission is non-prunable,
            // and confirmed success remains retained until this feature
            // journal advances. Older builds fail closed on those enum values.
            return .failedBeforeSubmission(
                errorClass: "interrupted_before_transport_staging"
            )
        }
        guard
            sora2Witness.account == mutation.account,
            sora2Witness.extrinsicHash == hash
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        switch sora2Witness.state {
        case .stagedBeforeTransport:
            return .failedBeforeSubmission(
                errorClass: "interrupted_before_transport_admission"
            )
        case .submitting, .submissionUnknown:
            return .submissionUnknown(
                errorClass: "interrupted_after_transport_admission"
            )
        case .submittedRetained, .submitted:
            return .submitted
        }
    }
}

enum PolkamarktPendingReconciliationPolicy {
    static func applying(
        _ resolutions: [String: PolkamarktPendingResolution],
        to latest: [PolkamarktPendingMutation],
        account: String,
        resolvedAt: Date
    ) throws -> [PolkamarktPendingMutation] {
        guard resolutions.allSatisfy({ element in
            let (hash, resolution) = element
            return PolkamarktTransactionHash.normalized(hash) == hash &&
                resolution.finalizedBlock >= 0
        }) else {
            throw PolkamarktRuntimeError.invalidTransactionHash
        }
        var merged = latest
        for index in merged.indices {
            guard
                merged[index].account == account,
                !merged[index].state.isTerminal,
                let hash = merged[index].extrinsicHash,
                let normalized = PolkamarktTransactionHash.normalized(hash),
                let resolution = resolutions[normalized]
            else {
                continue
            }
            merged[index].state = resolution.succeeded
                ? .finalized
                : .rejected
            merged[index].finalizedBlock = resolution.finalizedBlock
            merged[index].updatedAt = max(
                merged[index].updatedAt,
                resolvedAt
            )
            merged[index].errorClass = nil
        }
        return merged
    }
}

actor PolkamarktMutationAdmissionGate {
    static let shared = PolkamarktMutationAdmissionGate()

    // The durable Polkamarkt journal is one app-wide file. Serialize every
    // account through one token so two wallet coordinators cannot read the
    // same snapshot and publish conflicting replacements.
    private var activeAdmission: (account: String, token: UUID)?

    func acquire(account: String) throws -> UUID {
        guard !account.isEmpty, activeAdmission == nil else {
            throw PolkamarktRuntimeError.mutationInFlight
        }
        let token = UUID()
        activeAdmission = (account, token)
        return token
    }

    func release(account: String, token: UUID) {
        guard
            activeAdmission?.account == account,
            activeAdmission?.token == token
        else {
            return
        }
        activeAdmission = nil
    }
}

actor PolkamarktPendingStore {
    private static let maximumJournalBytes = 2 * 1_024 * 1_024
    private static let maximumMutations = 500

    private let directoryURL: URL
    private let fileURL: URL
    private let fileManager: FileManager
    private let sora2SubmissionStore: Sora2PendingSubmissionStore
    private let journalMutationLimit: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private struct IndexedInclusion: Hashable {
        let height: Int
        let blockHash: String
    }

    init(
        fileManager: FileManager = .default,
        baseURL: URL? = nil,
        journalMutationLimit: Int? = nil
    ) throws {
        let resolvedJournalMutationLimit =
            journalMutationLimit ?? Self.maximumMutations
        guard resolvedJournalMutationLimit >= 1,
              resolvedJournalMutationLimit <= Self.maximumMutations else {
            throw PolkamarktRuntimeError.unavailable
        }
        self.fileManager = fileManager
        self.journalMutationLimit = resolvedJournalMutationLimit
        let root: URL
        if let baseURL {
            root = baseURL
        } else {
            root = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        directoryURL = root
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        fileURL = directoryURL.appendingPathComponent("polkamarkt-v1.json")
        sora2SubmissionStore = try Sora2PendingSubmissionStore(
            fileManager: fileManager,
            baseURL: root
        )
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func all() throws -> [PolkamarktPendingMutation] {
        do {
            try PendingTransactionJournalNamespace.validate(
                directoryURL: directoryURL,
                fileManager: fileManager
            )
        } catch {
            throw PolkamarktRuntimeError.unavailable
        }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        // Atomic publication replaces the inode at this path. Build a fresh
        // URL for each read so Foundation cannot reuse the previous inode's
        // cached size and reject a valid state transition as corruption.
        let currentFileURL = URL(fileURLWithPath: fileURL.path)
        let values = try currentFileURL.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let fileSize = values.fileSize,
            fileSize >= 0,
            fileSize <= Self.maximumJournalBytes
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        let data = try Data(contentsOf: currentFileURL)
        guard
            data.count == fileSize,
            data.count <= Self.maximumJournalBytes
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        let mutations = try decoder.decode(
            [PolkamarktPendingMutation].self,
            from: data
        )
        guard
            mutations.count <= journalMutationLimit,
            Set(mutations.map(\.id)).count == mutations.count
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        try mutations.forEach(validate)
        let extrinsicHashes = mutations.compactMap {
            $0.extrinsicHash.flatMap(PolkamarktTransactionHash.normalized)
        }
        guard Set(extrinsicHashes).count == extrinsicHashes.count else {
            throw PolkamarktRuntimeError.invalidTransactionHash
        }
        return mutations
    }

    func requireMutationAdmission(account: String) throws {
        guard !account.isEmpty else {
            throw PolkamarktRuntimeError.pendingRecovery
        }
        let mutations = try all()
        guard mutations.allSatisfy({
            $0.account != account || $0.state.isTerminal
        }) else {
            throw PolkamarktRuntimeError.pendingRecovery
        }
    }

    @discardableResult
    func put(
        _ mutation: PolkamarktPendingMutation
    ) throws -> PolkamarktPendingMutation {
        try validate(mutation)
        let durableMutation = try canonicalizedForJournal(mutation)
        try validate(durableMutation)
        var values = try all()
        if let index = values.firstIndex(where: { $0.id == durableMutation.id }) {
            let existing = values[index]
            guard
                existing.account == durableMutation.account,
                existing.action == durableMutation.action,
                existing.marketIds == durableMutation.marketIds,
                Int(existing.createdAt.timeIntervalSince1970) ==
                    Int(durableMutation.createdAt.timeIntervalSince1970),
                existing.extrinsicHash == nil ||
                    existing.extrinsicHash == durableMutation.extrinsicHash
            else {
                throw PolkamarktRuntimeError.unavailable
            }
            if existing.state.isTerminal {
                // Finalized reconciliation can complete while an older RPC
                // callback is suspended. Terminal durable state wins and is
                // never regressed by that stale in-memory candidate.
                return existing
            }
            guard
                durableMutation.updatedAt >= existing.updatedAt,
                Self.canTransition(
                    from: existing.state,
                    to: durableMutation.state
                )
            else {
                throw PolkamarktRuntimeError.unavailable
            }
            values[index] = durableMutation
        } else {
            guard
                durableMutation.state == .preparing,
                durableMutation.extrinsicHash == nil,
                durableMutation.finalizedBlock == nil,
                durableMutation.errorClass == nil
            else {
                throw PolkamarktRuntimeError.unavailable
            }
            if values.count == journalMutationLimit {
                let sora2ByHash: [String: Sora2PendingSubmission]
                do {
                    sora2ByHash = Dictionary(
                        uniqueKeysWithValues: try sora2SubmissionStore.all()
                            .map { ($0.extrinsicHash, $0) }
                    )
                } catch {
                    // Journal capacity is never permission to discard the
                    // feature-side proof when its companion state is unreadable.
                    throw PolkamarktRuntimeError.unavailable
                }
                var safelyPrunableTerminalIndices: [Int] = []
                for index in values.indices where values[index].state.isTerminal {
                    if try terminalMutationCanBePruned(
                        values[index],
                        sora2ByHash: sora2ByHash
                    ) {
                        safelyPrunableTerminalIndices.append(index)
                    }
                }
                let oldestTerminalIndex = safelyPrunableTerminalIndices
                    .min(by: {
                        values[$0].updatedAt < values[$1].updatedAt
                    })
                guard let oldestTerminalIndex = oldestTerminalIndex else {
                    // Ambiguous or submitted mutations are never discarded
                    // simply to make room for a new transaction.
                    throw PolkamarktRuntimeError.unavailable
                }
                values.remove(at: oldestTerminalIndex)
            }
            values.append(durableMutation)
        }
        let extrinsicHashes = values.compactMap {
            $0.extrinsicHash.flatMap(PolkamarktTransactionHash.normalized)
        }
        guard Set(extrinsicHashes).count == extrinsicHashes.count else {
            throw PolkamarktRuntimeError.invalidTransactionHash
        }
        let data = try encoder.encode(values)
        guard data.count <= Self.maximumJournalBytes else {
            throw PolkamarktRuntimeError.unavailable
        }
        try DurableFileWriter.write(
            data,
            to: fileURL,
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )
        return durableMutation
    }

    /// A terminal feature row is the only durable explanation for a retained
    /// SORA2 witness during a cross-journal crash window. It may be evicted
    /// only when no companion exists or that companion is already prunable.
    private func terminalMutationCanBePruned(
        _ mutation: PolkamarktPendingMutation,
        sora2ByHash: [String: Sora2PendingSubmission]
    ) throws -> Bool {
        guard mutation.state.isTerminal else {
            return false
        }
        guard let rawHash = mutation.extrinsicHash else {
            return mutation.state == .failedBeforeSubmission
        }
        guard let hash = PolkamarktTransactionHash.normalized(rawHash) else {
            throw PolkamarktRuntimeError.invalidTransactionHash
        }
        guard let witness = sora2ByHash[hash] else {
            return true
        }
        guard witness.account == mutation.account else {
            throw PolkamarktRuntimeError.unavailable
        }
        return witness.isPrunable
    }

    private func canonicalizedForJournal(
        _ mutation: PolkamarktPendingMutation
    ) throws -> PolkamarktPendingMutation {
        do {
            // JSONEncoder's ISO-8601 strategy stores whole-second dates on
            // supported production systems. Compare and return the exact
            // durable representation so an immediate follow-up callback
            // cannot appear older merely because its predecessor rounded
            // while being published.
            return try decoder.decode(
                PolkamarktPendingMutation.self,
                from: encoder.encode(mutation)
            )
        } catch {
            throw PolkamarktRuntimeError.unavailable
        }
    }

    private static func canTransition(
        from current: PolkamarktPendingState,
        to next: PolkamarktPendingState
    ) -> Bool {
        if current == next {
            return true
        }
        switch (current, next) {
        case (.preparing, .failedBeforeSubmission),
             (.preparing, .signedBeforeTransport),
             (.signedBeforeTransport, .failedBeforeSubmission),
             (.signedBeforeTransport, .submissionUnknown),
             (.signedBeforeTransport, .submitted),
             (.submitting, .failedBeforeSubmission),
             (.submitting, .submitted),
             (.submitting, .submissionUnknown),
             (.submitting, .finalized),
             (.submitting, .rejected),
             (.submitted, .finalized),
             (.submitted, .rejected),
             (.submissionUnknown, .finalized),
             (.submissionUnknown, .rejected):
            return true
        default:
            return false
        }
    }

    private func validate(_ mutation: PolkamarktPendingMutation) throws {
        guard
            !mutation.account.isEmpty,
            mutation.account.utf8.count <= 512,
            mutation.action.range(
                of: #"^[a-z_]{1,64}$"#,
                options: .regularExpression
            ) != nil,
            !mutation.marketIds.isEmpty,
            mutation.marketIds.count <=
                PolkamarktRuntimeContract.maximumBatchClaims,
            Set(mutation.marketIds).count == mutation.marketIds.count,
            mutation.createdAt.timeIntervalSince1970.isFinite,
            mutation.updatedAt.timeIntervalSince1970.isFinite,
            mutation.updatedAt >= mutation.createdAt,
            mutation.errorClass.map({
                !$0.isEmpty &&
                    $0.utf8.count <= 256 &&
                    $0.rangeOfCharacter(from: .newlines) == nil
            }) ?? true
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        if let hash = mutation.extrinsicHash {
            guard PolkamarktTransactionHash.normalized(hash) != nil else {
                throw PolkamarktRuntimeError.invalidTransactionHash
            }
        } else {
            switch mutation.state {
            case .preparing, .failedBeforeSubmission:
                break
            default:
                throw PolkamarktRuntimeError.invalidTransactionHash
            }
        }
        if let finalizedBlock = mutation.finalizedBlock {
            guard finalizedBlock >= 0 else {
                throw PolkamarktRuntimeError.unavailable
            }
        }
        if [.finalized, .rejected].contains(mutation.state),
           mutation.finalizedBlock == nil {
            throw PolkamarktRuntimeError.unavailable
        }
    }

    func reconcileFinalizedHistory(
        account: String,
        client: PIIndexerClient,
        rpc: PolkamarktRPCClient,
        executionResults: @escaping (
            _ blockHash: String,
            _ extrinsicIndices: [String: UInt32]
        ) async throws -> [String: Bool]
    ) async throws -> [PolkamarktPendingMutation] {
        var values = try all()
        let sora2Submissions: [Sora2PendingSubmission]
        do {
            sora2Submissions = try sora2SubmissionStore.all()
        } catch {
            // Never infer pre-transport safety from an unreadable companion
            // journal. Keep the Polkamarkt entry unresolved and fail closed.
            throw PolkamarktRuntimeError.unavailable
        }
        let sora2ByHash = Dictionary(
            uniqueKeysWithValues: sora2Submissions.map {
                ($0.extrinsicHash, $0)
            }
        )
        var recoveredPreTransportState = false
        var preTransportWitnessesToRemove: [Sora2PendingSubmission] = []
        var confirmedWitnessesToAcknowledge:
            [Sora2PendingSubmission] = []
        for index in values.indices where values[index].account == account {
            if values[index].state == .preparing &&
                values[index].extrinsicHash == nil {
                values[index].state = .failedBeforeSubmission
                values[index].updatedAt = Date()
                values[index].errorClass =
                    "interrupted_before_signed_hash"
                recoveredPreTransportState = true
                continue
            }
            guard values[index].state == .signedBeforeTransport else {
                continue
            }
            guard
                let rawHash = values[index].extrinsicHash,
                let normalizedHash =
                    PolkamarktTransactionHash.normalized(rawHash)
            else {
                throw PolkamarktRuntimeError.invalidTransactionHash
            }
            let witness = sora2ByHash[normalizedHash]
            switch try PolkamarktPreTransportRecoveryPolicy.decision(
                for: values[index],
                sora2Witness: witness
            ) {
            case let .failedBeforeSubmission(errorClass):
                values[index].state = .failedBeforeSubmission
                values[index].updatedAt = Date()
                values[index].errorClass = errorClass
            case let .submissionUnknown(errorClass):
                values[index].state = .submissionUnknown
                values[index].updatedAt = Date()
                values[index].errorClass = errorClass
            case .submitted:
                values[index].state = .submitted
                values[index].updatedAt = Date()
                values[index].errorClass = nil
            }
            recoveredPreTransportState = true
        }
        // Finish a cross-journal transition that crashed after the feature
        // journal recorded transport success but before its retained SORA2
        // witness could be relaxed. Ambiguous witnesses require the separate
        // canonical-finality acknowledgement below.
        for value in values where value.account == account {
            guard
                let rawHash = value.extrinsicHash,
                let normalizedHash =
                    PolkamarktTransactionHash.normalized(rawHash),
                let witness = sora2ByHash[normalizedHash]
            else {
                continue
            }
            guard witness.account == value.account else {
                throw PolkamarktRuntimeError.unavailable
            }
            if value.state == .failedBeforeSubmission &&
                witness.state == .stagedBeforeTransport {
                preTransportWitnessesToRemove.append(witness)
            } else if value.state == .submitted &&
                [
                    Sora2PendingSubmissionState.submitting,
                    .submittedRetained,
                ].contains(witness.state) {
                confirmedWitnessesToAcknowledge.append(witness)
            }
        }
        if recoveredPreTransportState {
            // Publish the feature-journal decision before relaxing any SORA2
            // witness. A crash between journals therefore leaves the more
            // conservative, non-prunable side intact.
            try persistValidated(values)
        }
        do {
            for witness in preTransportWitnessesToRemove {
                try sora2SubmissionStore.removeBeforeSubmission(witness)
            }
            for witness in confirmedWitnessesToAcknowledge {
                try sora2SubmissionStore.acknowledgeRetainedSubmission(
                    account: witness.account,
                    hash: witness.extrinsicHash
                )
            }
        } catch {
            throw PolkamarktRuntimeError.unavailable
        }
        try acknowledgeDurableCanonicalTerminalWitnesses(
            account: account
        )
        var activeHashes = Set<String>()
        for value in values where
            value.account == account && !value.state.isTerminal
        {
            guard let hash = value.extrinsicHash else {
                continue
            }
            guard let normalized = PolkamarktTransactionHash.normalized(hash)
            else {
                throw PolkamarktRuntimeError.invalidTransactionHash
            }
            activeHashes.insert(normalized)
        }
        guard
            !activeHashes.isEmpty,
            activeHashes.count <= 100
        else {
            if activeHashes.isEmpty {
                return values
            }
            throw PolkamarktRuntimeError.unavailable
        }

        let historyRead = try await client
            .qualifiedHistoryByTransactionHashes(
                address: account,
                transactionHashes: Array(activeHashes).sorted()
            )
        guard
            let historyQualification = historyRead.qualification,
            historyQualification.source == .live,
            let historyCheckpoint =
                historyQualification.health.finalizedCheckpoint
        else {
            throw PolkamarktRuntimeError.unavailable
        }
        // The bounded hash lookup is attributed to one live PI checkpoint;
        // finalized SORA2 RPC remains the authority for inclusion, block
        // identity, and execution success.
        let checkpoint = historyCheckpoint
        let history = historyRead.value

        var indexed: [String: IndexedInclusion] = [:]
        func record(
            hash: String,
            accountMatches: Bool,
            height: Int?,
            blockHash: String?
        ) throws {
            guard
                let normalized = PolkamarktTransactionHash.normalized(hash),
                activeHashes.contains(normalized)
            else {
                return
            }
            guard
                accountMatches,
                let height,
                height >= 0,
                let blockHash,
                let normalizedBlockHash =
                    PolkamarktTransactionHash.normalized(blockHash)
            else {
                throw PolkamarktRuntimeError.unavailable
            }
            let inclusion = IndexedInclusion(
                height: height,
                blockHash: normalizedBlockHash
            )
            if let existing = indexed[normalized], existing != inclusion {
                throw PolkamarktRuntimeError.unavailable
            }
            indexed[normalized] = inclusion
        }
        for item in history {
            try record(
                hash: item.id,
                accountMatches:
                    item.address == account ||
                    item.dataFrom == account ||
                    item.dataTo == account,
                height: item.blockHeight,
                blockHash: item.blockHash
            )
        }

        let finalizedHeight = try await rpc.finalizedBlockNumber()
        var canonicalByHeight:
            [Int: (blockHash: String, executionResults: [String: Bool])] = [:]
        for inclusion in Set(indexed.values) where
            checkpoint >= inclusion.height
        {
            guard let canonical = try await rpc.canonicalExtrinsicHashes(
                at: inclusion.height,
                notAfter: finalizedHeight
            ) else {
                continue
            }
            let results = try await executionResults(
                canonical.blockHash,
                canonical.extrinsicIndices
            )
            canonicalByHeight[inclusion.height] = (
                canonical.blockHash,
                results
            )
        }

        var resolutions: [String: PolkamarktPendingResolution] = [:]
        for (hash, inclusion) in indexed {
            guard
                checkpoint >= inclusion.height,
                let canonical = canonicalByHeight[inclusion.height],
                canonical.blockHash == inclusion.blockHash,
                let succeeded = canonical.executionResults[hash]
            else {
                continue
            }
            resolutions[hash] = PolkamarktPendingResolution(
                finalizedBlock: inclusion.height,
                succeeded: succeeded
            )
        }

        // Every await above permits actor re-entry. Reload the journal and
        // merge only the captured hashes so a newly appended mutation or an
        // already-terminal result can never be erased or regressed.
        let latest = try all()
        let merged = try PolkamarktPendingReconciliationPolicy.applying(
            resolutions,
            to: latest,
            account: account,
            resolvedAt: Date()
        )
        if merged != latest {
            try persistValidated(merged)
        }
        try acknowledgeDurableCanonicalTerminalWitnesses(
            account: account
        )
        return merged
    }

    func acknowledgeDurableCanonicalTerminalWitnesses(
        account: String
    ) throws {
        try acknowledgeCanonicalTerminalWitnesses(
            in: try all(),
            account: account
        )
    }

    private func acknowledgeCanonicalTerminalWitnesses(
        in values: [PolkamarktPendingMutation],
        account: String
    ) throws {
        var hashes = Set<String>()
        for value in values where
            value.account == account &&
            [.finalized, .rejected].contains(value.state)
        {
            guard
                value.finalizedBlock != nil,
                let rawHash = value.extrinsicHash,
                let normalizedHash =
                    PolkamarktTransactionHash.normalized(rawHash)
            else {
                throw PolkamarktRuntimeError.unavailable
            }
            hashes.insert(normalizedHash)
        }
        do {
            try sora2SubmissionStore
                .acknowledgeAuthoritativelyFinalizedSubmissions(
                    account: account,
                    hashes: hashes
                )
        } catch {
            throw PolkamarktRuntimeError.unavailable
        }
    }

    func acknowledgeConfirmedTransport(
        account: String,
        hash: String
    ) throws {
        try sora2SubmissionStore.acknowledgeRetainedSubmission(
            account: account,
            hash: hash
        )
    }

    private func persistValidated(
        _ values: [PolkamarktPendingMutation]
    ) throws {
        guard values.count <= journalMutationLimit else {
            throw PolkamarktRuntimeError.unavailable
        }
        try values.forEach(validate)
        let data = try encoder.encode(values)
        guard data.count <= Self.maximumJournalBytes else {
            throw PolkamarktRuntimeError.unavailable
        }
        try DurableFileWriter.write(
            data,
            to: fileURL,
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )
    }
}

final class PolkamarktTransactionCoordinator {
    private let facade: WalletNetworkFacade
    private let operationFactory: WalletNetworkOperationFactory
    private let rpc: PolkamarktRPCClient
    private let statusEngine: JSONRPCEngine
    private let runtimeValidator: PolkamarktRuntimeValidator
    private let pendingStore: PolkamarktPendingStore
    private let settings: SettingsManagerProtocol
    private let selectedAccount: () -> AccountItem?
    private let featureClient: PIIndexerClient

    init?(
        walletContext: CommonWalletContextProtocol,
        pendingStore: PolkamarktPendingStore,
        settings: SettingsManagerProtocol = SettingsManager.shared,
        featureClient: PIIndexerClient = PIIndexerClient(),
        selectedAccount: @escaping () -> AccountItem? = {
            SelectedWalletSettings.shared.currentAccount
        }
    ) {
        guard
            let facade = walletContext.networkOperationFactory as? WalletNetworkFacade,
            let operationFactory =
                facade.nodeOperationFactory as? WalletNetworkOperationFactory
        else {
            return nil
        }
        self.facade = facade
        self.operationFactory = operationFactory
        statusEngine = Sora2BoundedHTTPJSONRPCEngine.wrapping(
            facade.engine
        )
        rpc = PolkamarktRPCClient(engine: statusEngine)
        runtimeValidator = PolkamarktRuntimeValidator(
            runtimeService: facade.runtimeService,
            rpc: rpc
        )
        self.pendingStore = pendingStore
        self.settings = settings
        self.featureClient = featureClient
        self.selectedAccount = selectedAccount
    }

    func reconcilePending(
        account: String
    ) async throws -> [PolkamarktPendingMutation] {
        let gate = PolkamarktMutationAdmissionGate.shared
        let token = try await gate.acquire(account: account)
        do {
            let result = try await reconcilePendingAdmitted(account: account)
            await gate.release(account: account, token: token)
            return result
        } catch {
            await gate.release(account: account, token: token)
            throw error
        }
    }

    private func reconcilePendingAdmitted(
        account: String
    ) async throws -> [PolkamarktPendingMutation] {
        try validateSelectedAccount(account)
        return try await pendingStore.reconcileFinalizedHistory(
            account: account,
            client: featureClient,
            rpc: rpc,
            executionResults: { [weak self] blockHash, indices in
                guard let self else {
                    throw PolkamarktRuntimeError.unavailable
                }
                // Definitive local pre-transport recovery above does not
                // depend on live metadata or connectivity. Resolve metadata
                // only when an indexed canonical inclusion actually needs
                // authoritative execution-event decoding.
                let factory = try await self.runtimeValidator.validate()
                return try await self.authoritativeExecutionResults(
                    at: blockHash,
                    extrinsicIndices: indices,
                    factory: factory
                )
            }
        )
    }

    func quote(
        account: String,
        marketId: UInt32,
        outcome: PolkamarktOutcome,
        side: PolkamarktSide,
        input: BigUInt,
        slippageBasisPoints: UInt16
    ) async throws -> PolkamarktQuoteConfirmation {
        // Quote preparation shares the same account slot as mutations and
        // recovery. It cannot produce a signable confirmation while an
        // unresolved or ambiguously submitted transaction exists.
        return try await withMutationAdmission(account: account) {
            try await self.quoteAdmitted(
                account: account,
                marketId: marketId,
                outcome: outcome,
                side: side,
                input: input,
                slippageBasisPoints: slippageBasisPoints
            )
        }
    }

    private func quoteAdmitted(
        account: String,
        marketId: UInt32,
        outcome: PolkamarktOutcome,
        side: PolkamarktSide,
        input: BigUInt,
        slippageBasisPoints: UInt16
    ) async throws -> PolkamarktQuoteConfirmation {
        try validateSelectedAccount(account)
        guard settings.polkamarktEnabled else {
            throw PolkamarktRuntimeError.unavailable
        }
        guard input > 0 else {
            throw PolkamarktRuntimeError.invalidAmount
        }
        guard (
            PolkamarktRuntimeContract.minimumMobileSlippageBasisPoints ...
                PolkamarktRuntimeContract.maximumMobileSlippageBasisPoints
        ).contains(slippageBasisPoints) else {
            throw PolkamarktRuntimeError.invalidSlippage
        }
        let factory = try await runtimeValidator.validate()
        let blockHash = try await rpc.finalizedHead()
        let authoritative = try await authoritativeMarket(
            marketId: marketId,
            at: blockHash,
            factory: factory
        )
        guard authoritative.effectiveStatus == .open else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        guard let runtimeState = try await rpc.marketState(
            marketId: marketId,
            at: blockHash
        ), runtimeState.marketId == marketId else {
            throw PolkamarktRuntimeError.marketUnavailable
        }

        switch side {
        case .buy:
            guard let quote = try await rpc.quoteBuy(
                marketId: marketId,
                outcome: outcome,
                collateralIn: input,
                at: blockHash
            ), quote.marketId == marketId,
               quote.collateralIn == input,
               quote.sharesOut > 0 else {
                throw PolkamarktRuntimeError.invalidQuote
            }
            try PolkamarktQuoteValidator.validateOutcome(
                quote.outcome,
                expected: outcome
            )
            let minimumOutput = try PolkamarktQuoteValidator.minimumOutput(
                quoteOutput: quote.sharesOut,
                slippageBasisPoints: slippageBasisPoints
            )
            let closure: ExtrinsicBuilderClosure = { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktBuy(
                        PolkamarktBuyCall(
                            marketId: marketId,
                            outcome: outcome,
                            collateralIn: input,
                            minSharesOut: minimumOutput
                        )
                    )
                )
            }
            async let networkFeeResult = estimateFee(closure)
            async let inputBalanceResult = rpc.freeBalance(
                account: account,
                assetId: WalletAssetId.kusd.rawValue,
                at: blockHash
            )
            async let xorBalanceResult = rpc.freeBalance(
                account: account,
                assetId: WalletAssetId.xor.rawValue,
                at: blockHash
            )
            let (networkFee, inputBalance, xorBalance) = try await (
                networkFeeResult,
                inputBalanceResult,
                xorBalanceResult
            )
            guard inputBalance >= input else {
                throw PolkamarktRuntimeError.insufficientKUSD
            }
            guard xorBalance >= networkFee else {
                throw PolkamarktRuntimeError.insufficientXOR
            }
            // Reject a wallet switch that completed while quote RPCs were in flight.
            try validateSelectedAccount(account)
            guard settings.polkamarktEnabled else {
                throw PolkamarktRuntimeError.unavailable
            }
            return PolkamarktQuoteConfirmation(
                finalizedBlockHash: blockHash,
                marketStatus: authoritative.effectiveStatus,
                closeBlock: authoritative.closeBlock,
                side: side,
                input: input,
                output: quote.sharesOut,
                marketFee: quote.feeAmount,
                networkFee: networkFee,
                minimumOutput: minimumOutput,
                inputBalance: inputBalance,
                xorBalance: xorBalance
            )
        case .sell:
            guard let quote = try await rpc.quoteSell(
                marketId: marketId,
                outcome: outcome,
                sharesIn: input,
                at: blockHash
            ), quote.marketId == marketId,
               quote.sharesIn == input,
               quote.collateralOut > 0 else {
                throw PolkamarktRuntimeError.invalidQuote
            }
            try PolkamarktQuoteValidator.validateOutcome(
                quote.outcome,
                expected: outcome
            )
            let minimumOutput = try PolkamarktQuoteValidator.minimumOutput(
                quoteOutput: quote.collateralOut,
                slippageBasisPoints: slippageBasisPoints
            )
            let rawPosition = try await rpc.claimable(
                account: account,
                marketId: marketId,
                at: blockHash
            )
            guard let position = try PolkamarktClaimValidator.validated(
                rawPosition,
                account: account,
                marketId: marketId
            ) else {
                throw PolkamarktRuntimeError.insufficientShares
            }
            let inputBalance = outcome == .yes
                ? position.yesShares
                : position.noShares
            guard inputBalance >= input else {
                throw PolkamarktRuntimeError.insufficientShares
            }
            let closure: ExtrinsicBuilderClosure = { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktSell(
                        PolkamarktSellCall(
                            marketId: marketId,
                            outcome: outcome,
                            sharesIn: input,
                            minCollateralOut: minimumOutput
                        )
                    )
                )
            }
            async let networkFeeResult = estimateFee(closure)
            async let xorBalanceResult = rpc.freeBalance(
                account: account,
                assetId: WalletAssetId.xor.rawValue,
                at: blockHash
            )
            let (networkFee, xorBalance) = try await (
                networkFeeResult,
                xorBalanceResult
            )
            guard xorBalance >= networkFee else {
                throw PolkamarktRuntimeError.insufficientXOR
            }
            // Reject a wallet switch that completed while quote RPCs were in flight.
            try validateSelectedAccount(account)
            guard settings.polkamarktEnabled else {
                throw PolkamarktRuntimeError.unavailable
            }
            return PolkamarktQuoteConfirmation(
                finalizedBlockHash: blockHash,
                marketStatus: authoritative.effectiveStatus,
                closeBlock: authoritative.closeBlock,
                side: side,
                input: input,
                output: quote.collateralOut,
                marketFee: quote.feeAmount,
                networkFee: networkFee,
                minimumOutput: minimumOutput,
                inputBalance: inputBalance,
                xorBalance: xorBalance
            )
        }
    }

    func authoritativeState(
        marketId: UInt32
    ) async throws -> PolkamarktMarketState {
        let review = try await authoritativeMarketReview(
            account: nil,
            marketId: marketId
        )
        return review.state
    }

    func authoritativeMarketReview(
        account: String?,
        marketId: UInt32
    ) async throws -> PolkamarktMarketReview {
        guard settings.polkamarktEnabled else {
            throw PolkamarktRuntimeError.unavailable
        }
        if let account {
            try validateSelectedAccount(account)
        }
        let factory = try await runtimeValidator.validate()
        let blockHash = try await rpc.finalizedHead()
        let authoritative = try await authoritativeMarket(
            marketId: marketId,
            at: blockHash,
            factory: factory
        )
        guard var state = try await rpc.marketState(
            marketId: marketId,
            at: blockHash
        ), state.marketId == marketId else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        state.finalizedStatus = authoritative.effectiveStatus
        let claimable: PolkamarktClaimable?
        if let account {
            claimable = try PolkamarktClaimValidator.validated(
                try await rpc.claimable(
                    account: account,
                    marketId: marketId,
                    at: blockHash
                ),
                account: account,
                marketId: marketId
            )
            try validateSelectedAccount(account)
        } else {
            claimable = nil
        }
        guard settings.polkamarktEnabled else {
            throw PolkamarktRuntimeError.unavailable
        }
        return PolkamarktMarketReview(
            finalizedBlockHash: blockHash,
            state: state,
            claimable: claimable
        )
    }

    func authoritativeClaimable(
        account: String,
        marketId: UInt32
    ) async throws -> PolkamarktClaimable? {
        let review = try await authoritativeClaimables(
            account: account,
            marketIds: [marketId]
        )
        return review.claims.first
    }

    func authoritativeClaimables(
        account: String,
        marketIds: [UInt32]
    ) async throws -> PolkamarktClaimReview {
        guard settings.polkamarktEnabled else {
            throw PolkamarktRuntimeError.unavailable
        }
        try validateSelectedAccount(account)
        guard
            !marketIds.isEmpty,
            marketIds.count <= PolkamarktRuntimeContract.maximumBatchClaims,
            Set(marketIds).count == marketIds.count
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        _ = try await runtimeValidator.validate()
        let blockHash = try await rpc.finalizedHead()
        let claims = try PolkamarktClaimValidator.reviewedClaims(
            try await claimables(
                account: account,
                marketIds: marketIds,
                at: blockHash
            ),
            account: account,
            requestedMarketIds: marketIds
        )
        try validateSelectedAccount(account)
        guard settings.polkamarktEnabled else {
            throw PolkamarktRuntimeError.unavailable
        }
        return PolkamarktClaimReview(
            account: account,
            finalizedBlockHash: blockHash,
            claims: claims
        )
    }

    func submitTrade(
        _ request: PolkamarktTradeRequest
    ) async throws -> PolkamarktPendingMutation {
        try await withMutationAdmission(account: request.account) {
            try await self.submitTradeAdmitted(request)
        }
    }

    private func submitTradeAdmitted(
        _ request: PolkamarktTradeRequest
    ) async throws -> PolkamarktPendingMutation {
        try validateSelectedAccount(request.account)
        try await validateLiveMutationFlags()
        guard request.input > 0 else {
            throw PolkamarktRuntimeError.invalidAmount
        }
        let factory = try await runtimeValidator.validate()

        let blockHash = try await rpc.finalizedHead()
        let authoritative = try await authoritativeMarket(
            marketId: request.marketId,
            at: blockHash,
            factory: factory
        )
        guard
            authoritative.effectiveStatus == .open,
            authoritative.closeBlock == request.confirmedCloseBlock
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        guard let runtimeState = try await rpc.marketState(
            marketId: request.marketId,
            at: blockHash
        ), runtimeState.marketId == request.marketId else {
            throw PolkamarktRuntimeError.marketUnavailable
        }

        let closure: ExtrinsicBuilderClosure
        switch request.side {
        case .buy:
            guard let quote = try await rpc.quoteBuy(
                marketId: request.marketId,
                outcome: request.outcome,
                collateralIn: request.input,
                at: blockHash
            ), quote.marketId == request.marketId,
               quote.collateralIn == request.input else {
                throw PolkamarktRuntimeError.invalidQuote
            }
            try PolkamarktQuoteValidator.validateOutcome(
                quote.outcome,
                expected: request.outcome
            )
            guard quote.feeAmount == request.confirmedMarketFee else {
                throw PolkamarktRuntimeError.staleQuote
            }
            try PolkamarktQuoteValidator.validate(
                refreshedOutput: quote.sharesOut,
                confirmedMinimum: request.minimumOutput
            )
            let kusd = try await rpc.freeBalance(
                account: request.account,
                assetId: WalletAssetId.kusd.rawValue,
                at: blockHash
            )
            guard kusd >= request.input else {
                throw PolkamarktRuntimeError.insufficientKUSD
            }
            closure = { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktBuy(
                        PolkamarktBuyCall(
                            marketId: request.marketId,
                            outcome: request.outcome,
                            collateralIn: request.input,
                            minSharesOut: request.minimumOutput
                        )
                    )
                )
            }
        case .sell:
            guard let quote = try await rpc.quoteSell(
                marketId: request.marketId,
                outcome: request.outcome,
                sharesIn: request.input,
                at: blockHash
            ), quote.marketId == request.marketId,
               quote.sharesIn == request.input else {
                throw PolkamarktRuntimeError.invalidQuote
            }
            try PolkamarktQuoteValidator.validateOutcome(
                quote.outcome,
                expected: request.outcome
            )
            guard quote.feeAmount == request.confirmedMarketFee else {
                throw PolkamarktRuntimeError.staleQuote
            }
            try PolkamarktQuoteValidator.validate(
                refreshedOutput: quote.collateralOut,
                confirmedMinimum: request.minimumOutput
            )
            let rawPosition = try await rpc.claimable(
                account: request.account,
                marketId: request.marketId,
                at: blockHash
            )
            guard let position = try PolkamarktClaimValidator.validated(
                rawPosition,
                account: request.account,
                marketId: request.marketId
            ) else {
                throw PolkamarktRuntimeError.insufficientShares
            }
            let available = request.outcome == .yes
                ? position.yesShares
                : position.noShares
            guard available >= request.input else {
                throw PolkamarktRuntimeError.insufficientShares
            }
            closure = { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktSell(
                        PolkamarktSellCall(
                            marketId: request.marketId,
                            outcome: request.outcome,
                            sharesIn: request.input,
                            minCollateralOut: request.minimumOutput
                        )
                    )
                )
            }
        }

        let quotedFee = try await estimateFee(closure)
        guard quotedFee <= request.maximumNetworkFee else {
            throw PolkamarktRuntimeError.staleQuote
        }
        let lifecycleLease =
            try await WalletLifecycleCoordinator.shared
                .acquireForMutableWalletAccessAsync()
        do {
            try Task.checkCancellation()
            let signingFee = try await estimateFee(closure)
            guard signingFee <= request.maximumNetworkFee else {
                throw PolkamarktRuntimeError.staleQuote
            }
            let signingBlockHash = try await rpc.finalizedHead()
            try await revalidateTradeBeforeSigning(
                request,
                fee: signingFee,
                at: signingBlockHash
            )

            // This is the final pre-sign gate. The extrinsic service resolves
            // call indices from its current metadata and validates that exact
            // factory while the same lifecycle lease remains active.
            try validateSelectedAccount(request.account)
            try await validateLiveMutationFlags()
            _ = try await runtimeValidator.validate()
            return try await submit(
                action:
                    "\(request.side.rawValue)_\(request.outcome.rawValue.lowercased())",
                account: request.account,
                marketIds: [request.marketId],
                closure: closure,
                lifecycleLease: lifecycleLease,
                validatedFinalizedHead: signingBlockHash,
                maximumNetworkFee: request.maximumNetworkFee
            )
        } catch {
            lifecycleLease.release()
            throw error
        }
    }

    func submitTraderClaim(
        _ confirmed: PolkamarktClaimAuthorization
    ) async throws -> PolkamarktPendingMutation {
        guard
            confirmed.kind == .traderPayout,
            confirmed.source == .selectedDetail,
            confirmed.marketIds.count == 1,
            let marketId = confirmed.marketIds.first
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        return try await withMutationAdmission(account: confirmed.account) {
            try await self.submitClaimAdmitted(
                action: PolkamarktRuntimeContract.Call.claimMarket,
                confirmed: confirmed
            ) { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktClaim(
                        PolkamarktMarketCall(marketId: marketId)
                    )
                )
            }
        }
    }

    func submitBatchClaim(
        _ confirmed: PolkamarktClaimAuthorization
    ) async throws -> PolkamarktPendingMutation {
        let marketIds = confirmed.marketIds
        guard
            confirmed.kind == .traderPayout,
            confirmed.source == .reviewedPositions,
            marketIds.count > 1,
            marketIds.count <= PolkamarktRuntimeContract.maximumBatchClaims,
            marketIds == Array(Set(marketIds)).sorted()
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        return try await withMutationAdmission(account: confirmed.account) {
            try await self.submitClaimAdmitted(
                action: PolkamarktRuntimeContract.Call.claimMarkets,
                confirmed: confirmed
            ) { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktBatchClaim(
                        PolkamarktBatchClaimCall(marketIds: marketIds)
                    )
                )
            }
        }
    }

    func submitCreatorFeeClaim(
        _ confirmed: PolkamarktClaimAuthorization
    ) async throws -> PolkamarktPendingMutation {
        guard
            confirmed.kind == .creatorFees,
            confirmed.source == .selectedDetail,
            confirmed.marketIds.count == 1,
            let marketId = confirmed.marketIds.first
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        return try await withMutationAdmission(account: confirmed.account) {
            try await self.submitClaimAdmitted(
                action: PolkamarktRuntimeContract.Call.claimCreatorFees,
                confirmed: confirmed
            ) { builder in
                try builder.adding(
                    call: RuntimeCall.polkamarktClaimCreatorFees(
                        PolkamarktMarketCall(marketId: marketId)
                    )
                )
            }
        }
    }

    private func submitClaimAdmitted(
        action: String,
        confirmed: PolkamarktClaimAuthorization,
        closure: @escaping ExtrinsicBuilderClosure
    ) async throws -> PolkamarktPendingMutation {
        let account = confirmed.account
        let marketIds = confirmed.marketIds
        try validateSelectedAccount(account)
        try await validateLiveMutationFlags()
        _ = try await runtimeValidator.validate()
        let blockHash = try await rpc.finalizedHead()
        let claims = try await claimables(
            account: account,
            marketIds: marketIds,
            at: blockHash
        )
        try PolkamarktClaimValidator.requireFreshAuthorization(
            confirmed,
            freshClaims: claims
        )
        let lifecycleLease =
            try await WalletLifecycleCoordinator.shared
                .acquireForMutableWalletAccessAsync()
        do {
            try Task.checkCancellation()
            let signingBlockHash = try await validateFeeAndSelection(
                account: account,
                closure: closure
            )
            let refreshedClaims = try await claimables(
                account: account,
                marketIds: marketIds,
                at: signingBlockHash
            )
            try PolkamarktClaimValidator.requireFreshAuthorization(
                confirmed,
                freshClaims: refreshedClaims
            )
            try validateSelectedAccount(account)
            try await validateLiveMutationFlags()
            _ = try await runtimeValidator.validate()
            return try await submit(
                action: action,
                account: account,
                marketIds: marketIds,
                closure: closure,
                lifecycleLease: lifecycleLease,
                validatedFinalizedHead: signingBlockHash
            )
        } catch {
            lifecycleLease.release()
            throw error
        }
    }

    private func validateFeeAndSelection(
        account: String,
        closure: @escaping ExtrinsicBuilderClosure
    ) async throws -> String {
        let fee = try await estimateFee(closure)
        let blockHash = try await rpc.finalizedHead()
        let xor = try await rpc.freeBalance(
            account: account,
            assetId: WalletAssetId.xor.rawValue,
            at: blockHash
        )
        guard xor >= fee else {
            throw PolkamarktRuntimeError.insufficientXOR
        }
        try validateSelectedAccount(account)
        try await validateLiveMutationFlags()
        _ = try await runtimeValidator.validate()
        return blockHash
    }

    private func withMutationAdmission<T>(
        account: String,
        operation: () async throws -> T
    ) async throws -> T {
        let gate = PolkamarktMutationAdmissionGate.shared
        let token = try await gate.acquire(account: account)
        do {
            try await pendingStore.requireMutationAdmission(account: account)
            let result = try await operation()
            await gate.release(account: account, token: token)
            return result
        } catch {
            await gate.release(account: account, token: token)
            throw error
        }
    }

    private func revalidateTradeBeforeSigning(
        _ request: PolkamarktTradeRequest,
        fee: BigUInt,
        at blockHash: String
    ) async throws {
        let factory = try await runtimeValidator.validate()
        let authoritative = try await authoritativeMarket(
            marketId: request.marketId,
            at: blockHash,
            factory: factory
        )
        guard
            authoritative.effectiveStatus == .open,
            authoritative.closeBlock == request.confirmedCloseBlock
        else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        guard let runtimeState = try await rpc.marketState(
            marketId: request.marketId,
            at: blockHash
        ), runtimeState.marketId == request.marketId else {
            throw PolkamarktRuntimeError.marketUnavailable
        }

        switch request.side {
        case .buy:
            guard let quote = try await rpc.quoteBuy(
                marketId: request.marketId,
                outcome: request.outcome,
                collateralIn: request.input,
                at: blockHash
            ), quote.marketId == request.marketId,
               quote.collateralIn == request.input else {
                throw PolkamarktRuntimeError.invalidQuote
            }
            try PolkamarktQuoteValidator.validateOutcome(
                quote.outcome,
                expected: request.outcome
            )
            guard quote.feeAmount == request.confirmedMarketFee else {
                throw PolkamarktRuntimeError.staleQuote
            }
            try PolkamarktQuoteValidator.validate(
                refreshedOutput: quote.sharesOut,
                confirmedMinimum: request.minimumOutput
            )
            let kusd = try await rpc.freeBalance(
                account: request.account,
                assetId: WalletAssetId.kusd.rawValue,
                at: blockHash
            )
            guard kusd >= request.input else {
                throw PolkamarktRuntimeError.insufficientKUSD
            }
        case .sell:
            guard let quote = try await rpc.quoteSell(
                marketId: request.marketId,
                outcome: request.outcome,
                sharesIn: request.input,
                at: blockHash
            ), quote.marketId == request.marketId,
               quote.sharesIn == request.input else {
                throw PolkamarktRuntimeError.invalidQuote
            }
            try PolkamarktQuoteValidator.validateOutcome(
                quote.outcome,
                expected: request.outcome
            )
            guard quote.feeAmount == request.confirmedMarketFee else {
                throw PolkamarktRuntimeError.staleQuote
            }
            try PolkamarktQuoteValidator.validate(
                refreshedOutput: quote.collateralOut,
                confirmedMinimum: request.minimumOutput
            )
            let rawPosition = try await rpc.claimable(
                account: request.account,
                marketId: request.marketId,
                at: blockHash
            )
            guard let position = try PolkamarktClaimValidator.validated(
                rawPosition,
                account: request.account,
                marketId: request.marketId
            ) else {
                throw PolkamarktRuntimeError.insufficientShares
            }
            let shares = request.outcome == .yes
                ? position.yesShares
                : position.noShares
            guard shares >= request.input else {
                throw PolkamarktRuntimeError.insufficientShares
            }
        }

        let xor = try await rpc.freeBalance(
            account: request.account,
            assetId: WalletAssetId.xor.rawValue,
            at: blockHash
        )
        guard xor >= fee else {
            throw PolkamarktRuntimeError.insufficientXOR
        }
    }

    private func authoritativeMarket(
        marketId: UInt32,
        at blockHash: String,
        factory: RuntimeCoderFactoryProtocol
    ) async throws -> PolkamarktAuthoritativeMarket {
        let blockHashData = try Data(hexStringSSF: blockHash)
        let header = try await rpc.header(at: blockHash)
        guard let observedBlock = BigUInt.fromHexString(header.number) else {
            throw PolkamarktRuntimeError.marketUnavailable
        }
        let storage = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        let wrapper: CompoundOperationWrapper<
            [StorageResponse<PolkamarktStoredMarket>]
        > = storage.queryItems(
            engine: statusEngine,
            keyParams: { [marketId] },
            factory: { factory },
            storagePath: .polkamarktMarkets,
            at: blockHashData
        )
        let stored = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<PolkamarktStoredMarket, Error>) in
            wrapper.targetOperation.completionBlock = {
                do {
                    guard
                        let value = try wrapper.targetOperation
                            .extractNoCancellableResultData()
                            .first?
                            .value
                    else {
                        throw PolkamarktRuntimeError.marketUnavailable
                    }
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            OperationManagerFacade.sharedDefaultQueue.addOperations(
                wrapper.allOperations,
                waitUntilFinished: false
            )
        }
        return PolkamarktAuthoritativeMarket(
            status: stored.status,
            closeBlock: stored.closeBlock,
            observedBlock: observedBlock
        )
    }

    private func authoritativeExecutionResults(
        at normalizedBlockHash: String,
        extrinsicIndices: [String: UInt32],
        factory: RuntimeCoderFactoryProtocol
    ) async throws -> [String: Bool] {
        guard
            PolkamarktTransactionHash.normalized(normalizedBlockHash) ==
                normalizedBlockHash,
            Set(extrinsicIndices.values).count == extrinsicIndices.count
        else {
            throw PolkamarktRuntimeError.invalidTransactionHash
        }
        let blockHash = "0x\(normalizedBlockHash)"
        let blockHashData = try Data(hexStringSSF: blockHash)
        let storageKey = try StorageKeyFactory().key(from: .events)
        let storage = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        let wrapper: CompoundOperationWrapper<
            [StorageResponse<[EventRecord]>]
        > = storage.queryItems(
            engine: statusEngine,
            keys: { [storageKey] },
            factory: { factory },
            storagePath: .events,
            at: blockHashData
        )
        let records = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[EventRecord], Error>) in
            wrapper.targetOperation.completionBlock = {
                do {
                    guard
                        let value = try wrapper.targetOperation
                            .extractNoCancellableResultData()
                            .first?
                            .value
                    else {
                        throw PolkamarktRuntimeError.unavailable
                    }
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            OperationManagerFacade.sharedDefaultQueue.addOperations(
                wrapper.allOperations,
                waitUntilFinished: false
            )
        }

        var results: [String: Bool] = [:]
        for (hash, extrinsicIndex) in extrinsicIndices {
            let terminal = records.filter {
                $0.extrinsicIndex == extrinsicIndex &&
                    $0.event.section == EventCodingPath.extrinsicSuccess.moduleName &&
                    (
                        $0.event.method ==
                            EventCodingPath.extrinsicSuccess.eventName ||
                            $0.event.method ==
                            EventCodingPath.extrinsicFailed.eventName
                    )
            }
            let successes = terminal.filter {
                $0.event.method == EventCodingPath.extrinsicSuccess.eventName
            }
            let failures = terminal.filter {
                $0.event.method == EventCodingPath.extrinsicFailed.eventName
            }
            guard successes.count <= 1, failures.count <= 1 else {
                throw PolkamarktRuntimeError.unavailable
            }
            if successes.count == 1, failures.isEmpty {
                results[hash] = true
            } else if failures.count == 1, successes.isEmpty {
                results[hash] = false
            }
        }
        return results
    }

    private func claimables(
        account: String,
        marketIds: [UInt32],
        at blockHash: String
    ) async throws -> [PolkamarktClaimable] {
        try await withThrowingTaskGroup(
            of: PolkamarktClaimable?.self
        ) { group in
            for marketId in marketIds {
                group.addTask {
                    try PolkamarktClaimValidator.validated(
                        try await self.rpc.claimable(
                            account: account,
                            marketId: marketId,
                            at: blockHash
                        ),
                        account: account,
                        marketId: marketId
                    )
                }
            }
            var result: [PolkamarktClaimable] = []
            for try await claim in group {
                if let claim {
                    result.append(claim)
                }
            }
            return result
        }
    }

    private func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure
    ) async throws -> BigUInt {
        try await withCheckedThrowingContinuation { continuation in
            operationFactory.extrinsicService.estimateFee(
                closure,
                runningIn: .global(qos: .userInitiated)
            ) { result in
                switch result {
                case let .success(value):
                    guard let fee = BigUInt(value), fee > 0 else {
                        continuation.resume(
                            throwing: PolkamarktRuntimeError.invalidQuote
                        )
                        return
                    }
                    continuation.resume(returning: fee)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func submit(
        action: String,
        account: String,
        marketIds: [UInt32],
        closure: @escaping ExtrinsicBuilderClosure,
        lifecycleLease: WalletLifecycleLease,
        validatedFinalizedHead: String,
        maximumNetworkFee: BigUInt? = nil
    ) async throws -> PolkamarktPendingMutation {
        try await validateLiveMutationFlags()
        let signer = operationFactory.accountSigner
        var pending = PolkamarktPendingMutation(
            id: UUID(),
            account: account,
            action: action,
            marketIds: marketIds,
            createdAt: Date(),
            updatedAt: Date(),
            extrinsicHash: nil,
            state: .preparing,
            finalizedBlock: nil,
            errorClass: nil
        )
        pending = try await pendingStore.put(pending)

        let qualification: PreparedExtrinsicFeeQualification
        do {
            // Journal persistence is an actor-reentrancy point. Recheck the
            // token-bound live snapshot synchronously at the prepare/sign
            // boundary before the extrinsic service may use the secret.
            try Task.checkCancellation()
            try validateSelectedAccount(account)
            try validateMutationFlags()
            let cancellable = CancellableCallRelay()
            qualification = try await withTaskCancellationHandler(
                operation: {
                    try await withCheckedThrowingContinuation {
                        continuation in
                        let call = operationFactory.extrinsicService
                            .prepareAndEstimateFee(
                                closure,
                                signer: signer,
                                lifecycleLease: lifecycleLease,
                                runtimeValidation: {
                                    try self.runtimeValidator
                                        .validateSigningFactory($0)
                                },
                                finalizedHeadValidation: { actualHead in
                                    try PolkamarktSigningHeadValidator.validate(
                                        expected: validatedFinalizedHead,
                                        actual: actualHead
                                    )
                                },
                                preSigningValidation: {
                                    // This closure executes after queued
                                    // nonce/head/metadata work and directly
                                    // adjacent to secret use.
                                    try self.validateSelectedAccount(account)
                                    try self.validateMutationFlags()
                                },
                                runningIn: .global(qos: .userInitiated)
                            ) { result in
                                continuation.resume(with: result)
                            }
                        cancellable.set(call)
                    }
                },
                onCancel: {
                    cancellable.cancel()
                }
            )
        } catch {
            pending.state = .failedBeforeSubmission
            pending.updatedAt = Date()
            pending.errorClass = String(describing: type(of: error))
            pending = try await pendingStore.put(pending)
            throw error
        }
        let prepared = qualification.prepared
        do {
            let exactFee = try PolkamarktExactFeeValidator.validate(
                rawFee: qualification.rawFee,
                maximumNetworkFee: maximumNetworkFee
            )
            let feeBlockHash = try await rpc.finalizedHead()
            let xorBalance = try await rpc.freeBalance(
                account: account,
                assetId: WalletAssetId.xor.rawValue,
                at: feeBlockHash
            )
            guard xorBalance >= exactFee else {
                throw PolkamarktRuntimeError.insufficientXOR
            }
            try Task.checkCancellation()
            try validateSelectedAccount(account)
            try validateMutationFlags()
        } catch {
            prepared.discard()
            pending.state = .failedBeforeSubmission
            pending.updatedAt = Date()
            pending.errorClass = String(describing: type(of: error))
            pending = try await pendingStore.put(pending)
            throw error
        }
        guard
            PolkamarktTransactionHash.normalized(prepared.hash) != nil
        else {
            prepared.discard()
            pending.state = .failedBeforeSubmission
            pending.updatedAt = Date()
            pending.errorClass = "invalid_local_transaction_hash"
            pending = try await pendingStore.put(pending)
            throw PolkamarktRuntimeError.invalidTransactionHash
        }
        do {
            try Task.checkCancellation()
            try validateSelectedAccount(account)
            try await validateLiveMutationFlags()
            _ = try await runtimeValidator.validate()
            try Task.checkCancellation()
            try validateSelectedAccount(account)
            try validateMutationFlags()
        } catch {
            prepared.discard()
            pending.state = .failedBeforeSubmission
            pending.updatedAt = Date()
            pending.errorClass = error is CancellationError
                ? "cancelled_before_submission"
                : String(describing: type(of: error))
            pending = try await pendingStore.put(pending)
            lifecycleLease.release()
            throw error
        }

        // All asynchronous checks are complete while the journal is still a
        // hashless `.preparing` entry. Persist the exact signed hash in a
        // distinct phase that recovery can classify only through the retained
        // SORA2 witness; legacy `.submitting` is never reinterpreted.
        pending.extrinsicHash = prepared.hash
        pending.state = .signedBeforeTransport
        pending.updatedAt = Date()
        pending = try await pendingStore.put(pending)

        // The exact signed hash is durable and all final checks/signing were
        // protected by this lease. The transport helper reacquires a fresh,
        // fully recovery-gated lease before consuming these one-shot bytes.
        lifecycleLease.release()
        let cancellable = CancellableCallRelay()
        let submission: Result<String, Error> = await
            withTaskCancellationHandler(
                operation: {
                    await withCheckedContinuation { continuation in
                        let call = operationFactory.extrinsicService
                            .submitPrepared(
                                prepared,
                                retainingTransportWitness: true,
                                expectedRawFee: qualification.rawFee,
                                preTransportValidation: { [weak self] in
                                    guard let self else {
                                        throw PolkamarktRuntimeError.unavailable
                                    }
                                    try self.validateSelectedAccount(account)
                                    try self.validateMutationFlags()
                                },
                                runningIn: .global(qos: .userInitiated)
                            ) { result in
                                continuation.resume(returning: result)
                            }
                        cancellable.set(call)
                    }
                },
                onCancel: {
                    cancellable.cancel()
                }
            )

        do {
            let returnedHash = try submission.get()
            guard
                let returned = PolkamarktTransactionHash.normalized(
                    returnedHash
                ),
                let local = PolkamarktTransactionHash.normalized(prepared.hash),
                returned == local
            else {
                throw PolkamarktRuntimeError.ambiguousSubmission
            }
            pending.state = .submitted
            pending.updatedAt = Date()
            do {
                pending = try await pendingStore.put(pending)
                try? await pendingStore.acknowledgeConfirmedTransport(
                    account: account,
                    hash: prepared.hash
                )
            } catch {
                // The exact signed hash and its non-prunable confirmed-success
                // witness remain durable. A post-success overlay update
                // failure must not report the chain submission as failed or
                // invite a retry.
            }
            return pending
        } catch let transportError as PreparedExtrinsicTransportError {
            switch transportError {
            case let .failedBeforeTransport(error):
                // The fresh recovery lease, final marker check, or local
                // configuration failed before signed bytes could enter RPC.
                pending.state = .failedBeforeSubmission
                pending.updatedAt = Date()
                pending.errorClass = String(
                    describing: type(of: error)
                )
                pending = try await pendingStore.put(pending)
                if [.finalized, .rejected].contains(pending.state) {
                    return pending
                }
                throw error
            case .submissionUnknown:
                let error = transportError.underlyingError
                pending.state = .submissionUnknown
                pending.updatedAt = Date()
                pending.errorClass = String(
                    describing: type(of: error)
                )
                pending = try await pendingStore.put(pending)
                if [.finalized, .rejected].contains(pending.state) {
                    return pending
                }
                throw PolkamarktRuntimeError.ambiguousSubmission
            }
        } catch {
            // The exact local hash was persisted before transport. Retain it
            // and reconcile from finalized PI history; never rebuild, sign or
            // submit this mutation again.
            pending.state = .submissionUnknown
            pending.updatedAt = Date()
            pending.errorClass = String(describing: type(of: error))
            pending = try await pendingStore.put(pending)
            if [.finalized, .rejected].contains(pending.state) {
                return pending
            }
            throw PolkamarktRuntimeError.ambiguousSubmission
        }
    }

    private func validateSelectedAccount(_ account: String) throws {
        guard
            let selected = selectedAccount(),
            selected.address == account,
            facade.address == account,
            selected.networkType == Chain.sora.addressType(),
            facade.networkType == Chain.sora.addressType()
        else {
            throw PolkamarktRuntimeError.wrongWalletOrNetwork
        }
    }

    private func validateMutationFlags() throws {
        guard settings.polkamarktEnabled, settings.polkamarktMutationsEnabled else {
            throw PolkamarktRuntimeError.mutationsDisabled
        }
    }

    private func validateLiveMutationFlags() async throws {
        let capabilitySession = ProductionRemoteCapabilitySession.shared
        let refreshToken = capabilitySession.beginLiveRefresh()
        let config: PIMobileConfig
        do {
            config = try await featureClient.mobileConfig(requireLive: true)
        } catch {
            capabilitySession.invalidate(refreshToken)
            throw error
        }
        guard settings.applyPIMobileConfig(
            config,
            refreshToken: refreshToken
        ) else {
            throw PolkamarktRuntimeError.mutationsDisabled
        }
        guard
            config.polkamarktVisible,
            config.polkamarktMutationsAvailable,
            settings.polkamarktEnabled,
            settings.polkamarktMutationsEnabled
        else {
            throw PolkamarktRuntimeError.mutationsDisabled
        }
    }
}
