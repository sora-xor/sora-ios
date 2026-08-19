// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import SoraKeystore

struct NexusExactDecimal: Comparable {
    let unscaled: BigInt
    let scale: Int

    init?(_ value: String) {
        guard
            !value.isEmpty,
            value.range(
                of: #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$"#,
                options: .regularExpression
            ) != nil
        else {
            return nil
        }
        let isNegative = value.first == "-"
        let unsigned = isNegative ? String(value.dropFirst()) : value
        let components = unsigned.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let integer = String(components[0])
        let fraction = components.count == 2 ? String(components[1]) : ""
        guard
            fraction.count <= NexusAmountPolicy.maximumScale,
            var unscaled = BigInt(integer + fraction)
        else {
            return nil
        }
        if isNegative {
            unscaled = -unscaled
        }
        self.unscaled = unscaled
        scale = fraction.count
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        let scale = max(lhs.scale, rhs.scale)
        let lhsValue = lhs.unscaled * powerOfTen(scale - lhs.scale)
        let rhsValue = rhs.unscaled * powerOfTen(scale - rhs.scale)
        return Self(unscaled: lhsValue + rhsValue, scale: scale)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let scale = max(lhs.scale, rhs.scale)
        return lhs.unscaled * powerOfTen(scale - lhs.scale) <
            rhs.unscaled * powerOfTen(scale - rhs.scale)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        let scale = max(lhs.scale, rhs.scale)
        return lhs.unscaled * powerOfTen(scale - lhs.scale) ==
            rhs.unscaled * powerOfTen(scale - rhs.scale)
    }

    private init(unscaled: BigInt, scale: Int) {
        self.unscaled = unscaled
        self.scale = scale
    }

    private static func powerOfTen(_ exponent: Int) -> BigInt {
        guard exponent > 0 else {
            return 1
        }
        return BigInt(10).power(exponent)
    }
}

enum NexusAmountPolicy {
    /// `iroha_primitives::numeric::Numeric` on the reviewed optimizations
    /// branch accepts canonical quantities only through scale 28. Taira's
    /// canonical public XOR definition is unconstrained, so read compatibility
    /// follows that ledger limit rather than imposing a separate UI scale.
    static let maximumScale = 28

    static func accepts(
        _ quantity: PIQuantity,
        allowingZero: Bool = false
    ) -> Bool {
        guard let value = NexusExactDecimal(quantity.rawValue) else {
            return false
        }
        return allowingZero ? value.unscaled >= 0 : value.unscaled > 0
    }
}

enum NexusSendAvailabilityPolicy {
    static func permits(
        networkId: NetworkId,
        nexusEnabled: Bool,
        sendsEnabled: Bool,
        tairaEnabled: Bool
    ) -> Bool {
        nexusEnabled &&
            sendsEnabled &&
            (networkId != .taira || tairaEnabled)
    }
}

enum NexusToriiError: LocalizedError {
    case invalidRoute
    case invalidResponse
    case responseTooLarge
    case httpStatus(Int)
    case server
    case transactionHashMismatch
    case ambiguousSubmission
    case confirmationAlreadySubmitted
    case nativeBridgeUnavailable
    case finalizedHeadUnavailable
    case sendsDisabled
    case wrongWalletOrNetwork
    case quoteChanged
    case quoteExpired
    case insufficientBalance

    var errorDescription: String? {
        switch self {
        case .invalidRoute:
            return "The selected Nexus network route is invalid."
        case .invalidResponse:
            return "Torii returned an invalid response."
        case .responseTooLarge:
            return "Torii returned more data than the mobile response limit."
        case let .httpStatus(code):
            return "Torii returned HTTP \(code)."
        case .server:
            // Torii text can echo an account or transaction payload.
            return "Torii rejected the requested operation."
        case .transactionHashMismatch:
            return "Torii returned a different transaction hash."
        case .ambiguousSubmission:
            return "Submission outcome is unknown. The transaction was not retried."
        case .confirmationAlreadySubmitted:
            return "This confirmation was already submitted. Review a new quote before trying again."
        case .nativeBridgeUnavailable:
            return "The reviewed Norito signing bridge is unavailable."
        case .finalizedHeadUnavailable:
            return "The reviewed network-bound finalized-head reader is unavailable."
        case .sendsDisabled:
            return "Nexus sends are temporarily disabled."
        case .wrongWalletOrNetwork:
            return "The selected wallet or network changed before signing."
        case .quoteChanged:
            return "The network fee quote changed. Review the send again before signing."
        case .quoteExpired:
            return "The network fee quote expired. Review the send again before signing."
        case .insufficientBalance:
            return "The XOR balance is insufficient for the amount and fee."
        }
    }
}

enum NexusTransactionHash {
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

enum NexusJSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case string(String)
    case number(String)
    case array([NexusJSONValue])
    case object([String: NexusJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .number(String(value))
        } else if let value = try? container.decode(UInt64.self) {
            self = .number(String(value))
        } else if let value = try? container.decode([NexusJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(
            [String: NexusJSONValue].self
        ) {
            self = .object(value)
        } else {
            // Foundation Decimal silently rounds sufficiently large JSON
            // numbers. Nexus quantities must be strings; only bounded exact
            // integer control fields are accepted as numeric JSON tokens.
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Nexus numeric values must be exact 64-bit integers or strings."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            if let signed = Int64(value), String(signed) == value {
                try container.encode(signed)
            } else if let unsigned = UInt64(value),
                      String(unsigned) == value {
                try container.encode(unsigned)
            } else {
                throw NexusToriiError.invalidResponse
            }
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

private extension NexusJSONValue {
    var objectValue: [String: NexusJSONValue]? {
        guard case let .object(value) = self else {
            return nil
        }
        return value
    }

    var arrayValue: [NexusJSONValue]? {
        guard case let .array(value) = self else {
            return nil
        }
        return value
    }

    var stringValue: String? {
        switch self {
        case let .string(value), let .number(value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return nil
        }
    }

    var exactWireStringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var boolValue: Bool? {
        guard case let .bool(value) = self else {
            return nil
        }
        return value
    }
}

struct NexusAssetDefinition: Decodable, Equatable {
    struct AliasBinding: Decodable, Equatable {
        let alias: String
        let status: String
        let leaseExpiryMilliseconds: UInt64?
        let graceUntilMilliseconds: UInt64?
        let boundAtMilliseconds: UInt64

        private enum CodingKeys: String, CodingKey {
            case alias
            case status
            case leaseExpiryMilliseconds = "lease_expiry_ms"
            case graceUntilMilliseconds = "grace_until_ms"
            case boundAtMilliseconds = "bound_at_ms"
        }
    }

    let id: String
    let name: String
    let alias: String
    let aliasBinding: AliasBinding

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case alias
        case aliasBinding = "alias_binding"
    }
}

enum NexusAssetDefinitionIdentity {
    static let xorAlias = "xor#universal"
    static let xorName = "xor"

    private static let base58Alphabet = Array(
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8
    )
    private static let base58Values = Dictionary(
        uniqueKeysWithValues: base58Alphabet.enumerated().map {
            ($0.element, $0.offset)
        }
    )

    /// Performs the transport-level portion of Iroha's canonical opaque
    /// asset-definition validation. The reviewed native signer remains
    /// responsible for the BLAKE3 checksum before it constructs a quote or
    /// signed payload; mobile rejects aliases, malformed Base58, wrong
    /// versions, and non-UUIDv4 payloads before those bytes reach the bridge.
    static func hasCanonicalWireShape(_ value: String) -> Bool {
        guard
            value.utf8.count == 28,
            value == value.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return false
        }
        var decoded = BigUInt(0)
        for byte in value.utf8 {
            guard let digit = base58Values[byte] else {
                return false
            }
            decoded = decoded * BigUInt(58) + BigUInt(digit)
        }
        let payload = [UInt8](decoded.serialize())
        guard
            payload.count == 21,
            payload[0] == 1,
            payload[7] >> 4 == 0b0100,
            payload[9] & 0b1100_0000 == 0b1000_0000
        else {
            return false
        }
        return true
    }

    static func validateXor(_ definition: NexusAssetDefinition) throws {
        guard
            hasCanonicalWireShape(definition.id),
            definition.name == xorName,
            definition.alias == xorAlias,
            definition.aliasBinding.alias == xorAlias,
            ["permanent", "leased_active"].contains(
                definition.aliasBinding.status
            )
        else {
            throw NexusToriiError.invalidResponse
        }
    }
}

struct NexusAccountAssetList: Decodable, Equatable {
    struct Item: Decodable, Equatable, Identifiable {
        let accountID: String?
        let asset: String
        let assetID: String?
        let assetName: String?
        let assetAlias: String?
        let quantity: PIQuantity
        let scope: String?

        var id: String { assetID ?? asset }

        private enum CodingKeys: String, CodingKey {
            case accountID = "account_id"
            case asset
            case assetID = "asset_id"
            case assetName = "asset_name"
            case assetAlias = "asset_alias"
            case quantity
            case scope
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
            assetID = try container.decodeIfPresent(String.self, forKey: .assetID)
            // Torii's canonical account-assets schema makes `asset` authoritative.
            // `asset_id` is only a redundant identity witness and must never rescue a
            // missing canonical field, otherwise Android and iOS can bind different assets.
            asset = try container.decode(String.self, forKey: .asset)
            guard !asset.isEmpty else {
                throw NexusToriiError.invalidResponse
            }
            assetName = try container.decodeIfPresent(String.self, forKey: .assetName)
            assetAlias = try container.decodeIfPresent(String.self, forKey: .assetAlias)
            quantity = try container.decode(PIQuantity.self, forKey: .quantity)
            scope = try container.decodeIfPresent(String.self, forKey: .scope)
        }
    }

    let items: [Item]
    let hasMore: Bool
    let countMode: String
    let total: Int64

    private enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case countMode = "count_mode"
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedItems = try container.decode(
            [Item].self,
            forKey: .items
        )
        let decodedTotal = try container.decode(Int64.self, forKey: .total)
        guard
            decodedTotal >= 0,
            decodedTotal >= Int64(decodedItems.count)
        else {
            throw NexusToriiError.invalidResponse
        }
        items = decodedItems
        total = decodedTotal
        hasMore = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasMore
        ) ?? (decodedTotal > Int64(decodedItems.count))
        countMode = try container.decodeIfPresent(
            String.self,
            forKey: .countMode
        ) ?? "exact"
    }
}

enum NexusBalanceValidator {
    static func xorBalance(
        in response: NexusAccountAssetList,
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) throws -> PIQuantity {
        try exactAssetBalance(
            in: response,
            account: account,
            configuration: configuration,
            assetDefinitionID: assetDefinitionID,
            expectedAssetName: NexusAssetDefinitionIdentity.xorName,
            expectedAssetAlias: NexusAssetDefinitionIdentity.xorAlias
        )
    }

    /// Recovery binds to the journaled opaque definition and deliberately
    /// leaves mutable name/alias metadata unconstrained.
    static func exactAssetBalance(
        in response: NexusAccountAssetList,
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        expectedAssetName: String? = nil,
        expectedAssetAlias: String? = nil
    ) throws -> PIQuantity {
        guard NexusAssetDefinitionIdentity.hasCanonicalWireShape(
            assetDefinitionID
        ) else {
            throw NexusToriiError.invalidResponse
        }
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        guard
            response.items.count <= 500,
            !response.hasMore,
            response.total == Int64(response.items.count),
            response.countMode == "exact"
        else {
            throw NexusToriiError.invalidResponse
        }

        for item in response.items {
            guard
                item.asset == assetDefinitionID,
                item.assetID == nil ||
                    item.assetID == assetDefinitionID,
                expectedAssetName.map({ item.assetName == $0 }) ?? true,
                expectedAssetAlias.map({ item.assetAlias == $0 }) ?? true,
                item.scope == "global",
                NexusAmountPolicy.accepts(
                    item.quantity,
                    allowingZero: true
                ),
                let accountID = item.accountID,
                let itemAccount = try? IrohaAddressCodec.parse(
                    accountID,
                    expectedDiscriminant:
                        configuration.i105Discriminant
                ).i105,
                itemAccount == canonicalAccount
            else {
                throw NexusToriiError.invalidResponse
            }
        }
        guard response.items.count <= 1 else {
            throw NexusToriiError.invalidResponse
        }
        if let balance = response.items.first?.quantity {
            return balance
        }
        return try PIQuantity("0")
    }
}

struct NexusAccountTransactionList: Decodable, Equatable {
    struct Item: Decodable, Equatable, Identifiable {
        let authority: String?
        let timestampMilliseconds: UInt64?
        let entrypointHash: String
        let succeeded: Bool

        var id: String { entrypointHash }

        private enum CodingKeys: String, CodingKey {
            case authority
            case timestampMilliseconds = "timestamp_ms"
            case entrypointHash = "entrypoint_hash"
            case succeeded = "result_ok"
        }
    }

    let items: [Item]
    let total: UInt64
    let hasMore: Bool
    let countMode: String

    private enum CodingKeys: String, CodingKey {
        case items
        case total
        case hasMore = "has_more"
        case countMode = "count_mode"
    }
}

enum NexusAccountTransactionProofResult: Equatable {
    case continueScanning
    case found
    case absent
}

/// Transport-independent validation for Torii's exact account-history snapshot.
struct NexusAccountTransactionProof {
    private let configuration: NexusNetworkConfiguration
    private let canonicalAccount: String
    private let expectedHash: String
    private let pageSize: Int
    private let maximumPages: Int
    private var expectedTotal: UInt64?
    private var seenHashes = Set<String>()
    private var pageFingerprints = Set<String>()
    private var pagesAccepted = 0

    private(set) var nextOffset = 0

    init(
        account: String,
        configuration: NexusNetworkConfiguration,
        transactionHash: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) throws {
        guard
            (1 ... 100).contains(pageSize),
            maximumPages > 0,
            let expectedHash = NexusTransactionHash.normalized(
                transactionHash
            )
        else {
            throw NexusToriiError.invalidRoute
        }
        self.configuration = configuration
        canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        self.expectedHash = expectedHash
        self.pageSize = pageSize
        self.maximumPages = maximumPages
    }

    mutating func accept(
        _ page: NexusAccountTransactionList
    ) throws -> NexusAccountTransactionProofResult {
        guard
            pagesAccepted < maximumPages,
            page.countMode == "exact",
            page.items.count <= pageSize,
            expectedTotal.map({ $0 == page.total }) ?? true,
            UInt64(nextOffset) <= page.total,
            UInt64(page.items.count) <= page.total - UInt64(nextOffset),
            page.hasMore == (
                UInt64(nextOffset) + UInt64(page.items.count) < page.total
            )
        else {
            throw NexusToriiError.invalidResponse
        }
        expectedTotal = page.total
        pagesAccepted += 1

        let normalizedItems = try page.items.map { item -> String in
            guard let normalized = NexusTransactionHash.normalized(
                item.entrypointHash
            ) else {
                throw NexusToriiError.invalidResponse
            }
            return normalized
        }
        if !normalizedItems.isEmpty {
            let fingerprint = normalizedItems.joined(separator: ":")
            guard pageFingerprints.insert(fingerprint).inserted else {
                throw NexusToriiError.invalidResponse
            }
        }
        for normalized in normalizedItems {
            guard seenHashes.insert(normalized).inserted else {
                throw NexusToriiError.invalidResponse
            }
        }

        if let index = normalizedItems.firstIndex(of: expectedHash) {
            let item = page.items[index]
            guard
                item.succeeded,
                let authority = item.authority,
                let canonicalAuthority = try? IrohaAddressCodec.parse(
                    authority,
                    expectedDiscriminant:
                        configuration.i105Discriminant
                ).i105,
                canonicalAuthority == canonicalAccount
            else {
                throw NexusToriiError.invalidResponse
            }
            return .found
        }

        nextOffset += page.items.count
        if UInt64(nextOffset) == page.total {
            return .absent
        }
        guard !page.items.isEmpty, pagesAccepted < maximumPages else {
            throw NexusToriiError.invalidResponse
        }
        return .continueScanning
    }
}

struct NexusTransferHistoryItem: Equatable, Identifiable {
    var id: String {
        "\(transactionHash):\(sender):\(receiver):\(amount.rawValue)"
    }

    let transactionHash: String
    let timestampMilliseconds: Int64
    let amount: PIQuantity
    let sender: String
    let receiver: String
}

enum NexusCommittedHistoryReconciliation {
    /// A finalized transaction is reconciled only when the account-scoped
    /// committed history contains one, and only one, transfer matching every
    /// signed field. Accepting `contains` here would make duplicate or
    /// conflicting Torii evidence look authoritative.
    static func matchesExactlyOne(
        history: [NexusTransferHistoryItem],
        transactionHash: String,
        sender: String,
        receiver: String,
        amount: NexusExactDecimal
    ) -> Bool {
        guard let expectedHash = NexusTransactionHash.normalized(
            transactionHash
        ) else {
            return false
        }
        // The reviewed signer constructs one XOR transfer. Therefore every
        // transfer projected for the signed hash is part of the proof, not an
        // unrelated row that may be ignored. Reject duplicate or conflicting
        // instructions under that hash before comparing the exact fields.
        let transfersForSignedHash = history.filter {
            NexusTransactionHash.normalized($0.transactionHash) ==
                expectedHash
        }
        guard
            transfersForSignedHash.count == 1,
            let transfer = transfersForSignedHash.first,
            let actualAmount = NexusExactDecimal(
                transfer.amount.rawValue
            )
        else {
            return false
        }
        return transfer.sender == sender &&
            transfer.receiver == receiver &&
            actualAmount == amount
    }
}

private struct NexusMCPRequest: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method = "tools/call"
    let params: NexusJSONValue
}

private struct NexusMCPResponse: Decodable {
    struct Failure: Decodable {
        let code: Int
    }

    let jsonrpc: String
    let id: String?
    let result: NexusJSONValue?
    let error: Failure?
}

enum NexusMCPEnvelopeContract {
    static func validate(
        jsonrpc: String,
        responseID: String?,
        expectedID: String,
        hasError: Bool
    ) throws {
        guard jsonrpc == "2.0", responseID == expectedID else {
            throw NexusToriiError.invalidResponse
        }
        guard !hasError else {
            throw NexusToriiError.server
        }
    }
}

/// Rejects ambiguous or profiled media types before either an HTTP or MCP-embedded body is used.
enum NexusToriiMediaTypeContract {
    static func matches(_ value: String?, expected: String) -> Bool {
        guard
            let value,
            value == value.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.contains(",")
        else {
            return false
        }
        let parts = value.components(separatedBy: ";")
        guard
            (1 ... 2).contains(parts.count),
            parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                == expected
        else {
            return false
        }
        return parts.count == 1 ||
            parts[1].trimmingCharacters(in: .whitespaces)
                .lowercased() == "charset=utf-8"
    }
}

/// Validates the HTTP response Torii embeds inside a successful MCP tool result.
enum NexusMCPResultContract {
    static func validateEmbeddedRoute(
        _ result: NexusJSONValue,
        requiresFanout: Bool = false
    ) throws -> NexusJSONValue {
        guard
            let direct = result.objectValue,
            direct["isError"]?.boolValue == false,
            direct["body"] == nil,
            direct["items"] == nil,
            let structured = direct["structuredContent"]?.objectValue,
            let statusValue = structured["status"],
            case let .number(statusRaw) = statusValue,
            let status = Int(statusRaw),
            String(status) == statusRaw,
            (200 ... 299).contains(status),
            let contentTypeValue = structured["content_type"],
            case let .string(contentType) = contentTypeValue,
            NexusToriiMediaTypeContract.matches(
                contentType,
                expected: "application/json"
            ),
            structured["body"]?.objectValue != nil,
            structured["items"] == nil,
            let rawHeaders = structured["headers"]?.objectValue
        else {
            throw NexusToriiError.invalidResponse
        }

        var headers: [String: String] = [:]
        for (name, value) in rawHeaders {
            guard
                !name.isEmpty,
                case let .string(raw) = value,
                raw == raw.trimmingCharacters(in: .whitespacesAndNewlines)
            else {
                throw NexusToriiError.invalidResponse
            }
            let normalizedName = name.lowercased()
            guard headers.updateValue(raw, forKey: normalizedName) == nil else {
                throw NexusToriiError.invalidResponse
            }
        }
        // Some curated MCP routes legitimately emit no fanout family. A
        // caller consuming global instruction history opts into the stricter
        // contract: every fanout count must be present and all attempted
        // routes must have succeeded before the embedded body is trusted.
        try NexusToriiClient.validateFanoutHeaderValues(
            { headers[$0] },
            requiresFanout: requiresFanout
        )
        return .object(structured)
    }
}

struct NexusTransferHistoryPage {
    let items: [NexusTransferHistoryItem]
    let sourceItemCount: Int
}

enum NexusTransferHistoryParser {
    private static let millisecondThreshold: Int64 = 10_000_000_000

    static func page(
        result: NexusJSONValue,
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> NexusTransferHistoryPage {
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        let root = try unwrap(result)
        let body = root["body"]?.objectValue ?? root
        guard let sourceItems = body["items"]?.arrayValue else {
            throw NexusToriiError.invalidResponse
        }

        let items = try sourceItems.flatMap { value -> [NexusTransferHistoryItem] in
            guard let object = value.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            return try parseInstruction(
                object,
                configuration: configuration,
                account: canonicalAccount,
                assetDefinitionID: assetDefinitionID
            )
        }
        return NexusTransferHistoryPage(
            items: items,
            sourceItemCount: sourceItems.count
        )
    }

    private static func unwrap(
        _ result: NexusJSONValue
    ) throws -> [String: NexusJSONValue] {
        guard let direct = result.objectValue else {
            throw NexusToriiError.invalidResponse
        }
        if direct["isError"]?.boolValue == true {
            throw NexusToriiError.server
        }
        if direct["body"] != nil || direct["items"] != nil {
            return direct
        }
        if let structured = direct["structuredContent"]?.objectValue {
            return structured
        }
        guard
            let content = direct["content"]?.arrayValue,
            let text = content.lazy.compactMap({ item -> String? in
                guard
                    let object = item.objectValue,
                    object["type"]?.stringValue == "text"
                else {
                    return nil
                }
                return object["text"]?.stringValue
            }).first,
            let decoded = try? JSONDecoder().decode(
                NexusJSONValue.self,
                from: Data(text.utf8)
            ),
            let object = decoded.objectValue
        else {
            throw NexusToriiError.invalidResponse
        }
        return object
    }

    private static func parseInstruction(
        _ object: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> [NexusTransferHistoryItem] {
        guard
            let status = firstString(
                in: object,
                keys: ["transaction_status", "transactionStatus", "status"]
            )
        else {
            throw NexusToriiError.invalidResponse
        }
        guard status.caseInsensitiveCompare("committed") == .orderedSame else {
            return []
        }
        guard
            let rawHash = firstString(
                in: object,
                keys: ["transaction_hash", "transactionHash", "hash"]
            ),
            let hash = normalizedHash(rawHash),
            let rawTimestamp = firstString(
                in: object,
                keys: ["created_at", "createdAt", "timestamp"]
            ),
            let timestamp = timestampMilliseconds(rawTimestamp),
            let payload = object["box"]?.objectValue?["json"]?
                .objectValue?["payload"]?.objectValue,
            let variant = payload["variant"]?.stringValue
        else {
            throw NexusToriiError.invalidResponse
        }

        let transfers: [(amount: PIQuantity, sender: String, receiver: String)]
        switch variant {
        case "Asset":
            guard let value = payload["value"]?.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            transfers = try parseTransfer(
                value,
                configuration: configuration,
                account: account,
                assetDefinitionID: assetDefinitionID
            ).map { [$0] } ?? []
        case "AssetBatch":
            guard
                let value = payload["value"]?.objectValue,
                let entries = ["entries", "transfers", "items"]
                    .lazy
                    .compactMap({ value[$0]?.arrayValue })
                    .first
            else {
                throw NexusToriiError.invalidResponse
            }
            transfers = try entries.compactMap {
                guard let entry = $0.objectValue else {
                    throw NexusToriiError.invalidResponse
                }
                return try parseBatchTransfer(
                    entry,
                    configuration: configuration,
                    account: account,
                    assetDefinitionID: assetDefinitionID
                )
            }
        default:
            transfers = []
        }

        return transfers.map {
            NexusTransferHistoryItem(
                transactionHash: hash,
                timestampMilliseconds: timestamp,
                amount: $0.amount,
                sender: $0.sender,
                receiver: $0.receiver
            )
        }
    }

    private static func parseBatchTransfer(
        _ object: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> (amount: PIQuantity, sender: String, receiver: String)? {
        guard let definition = firstString(
            in: object,
            keys: [
                "asset_definition", "assetDefinition",
                "asset_definition_id",
            ]
        ) else {
            throw NexusToriiError.invalidResponse
        }
        guard definition == assetDefinitionID else {
            return nil
        }
        return try parseTransfer(
            object,
            configuration: configuration,
            account: account,
            assetDefinitionID: assetDefinitionID
        )
    }

    private static func parseTransfer(
        _ object: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> (amount: PIQuantity, sender: String, receiver: String)? {
        let source = firstString(
            in: object,
            keys: [
                "source", "source_id", "asset", "asset_id",
                "asset_definition", "assetDefinition",
                "asset_definition_id",
            ]
        )
        let embeddedSourceAccount: String?
        if let source {
            if source == assetDefinitionID {
                embeddedSourceAccount = nil
            } else if source.hasPrefix("\(assetDefinitionID)#") {
                let candidate = String(
                    source.dropFirst(assetDefinitionID.count + 1)
                )
                guard !candidate.isEmpty, !candidate.contains("#") else {
                    throw NexusToriiError.invalidResponse
                }
                embeddedSourceAccount = candidate
            } else {
                return nil
            }
        } else {
            embeddedSourceAccount = nil
        }
        guard
            let destination = firstString(
                in: object,
                keys: ["destination", "destination_id", "to", "account_id"]
            ),
            let amountValue = ["object", "amount", "quantity", "value"]
                .lazy
                .compactMap({ object[$0] })
                .first,
            let amount = try parseAmount(amountValue)
        else {
            throw NexusToriiError.invalidResponse
        }
        let explicitSourceAccount = firstString(
            in: object,
            keys: ["source_account", "from", "account"]
        )

        let canonicalDestination = try IrohaAddressCodec.parse(
            destination,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        let canonicalExplicitSource = try explicitSourceAccount.map {
            try IrohaAddressCodec.parse(
                $0,
                expectedDiscriminant: configuration.i105Discriminant
            ).i105
        }
        let canonicalEmbeddedSource = try embeddedSourceAccount.map {
            try IrohaAddressCodec.parse(
                $0,
                expectedDiscriminant: configuration.i105Discriminant
            ).i105
        }
        if let canonicalExplicitSource,
           let canonicalEmbeddedSource,
           canonicalExplicitSource != canonicalEmbeddedSource {
            throw NexusToriiError.invalidResponse
        }
        let canonicalSource = canonicalExplicitSource ??
            canonicalEmbeddedSource
        let incoming = canonicalDestination == account
        let outgoing = canonicalSource == account
        guard incoming || outgoing else {
            return nil
        }
        guard let sender = outgoing ? account : canonicalSource else {
            throw NexusToriiError.invalidResponse
        }
        let receiver = incoming ? account : canonicalDestination
        return (amount, sender, receiver)
    }

    private static func parseAmount(
        _ value: NexusJSONValue
    ) throws -> PIQuantity? {
        let raw: String?
        if let string = value.exactWireStringValue {
            guard
                string.utf8.count <= PIQuantity.maximumWireBytes
            else {
                throw NexusToriiError.invalidResponse
            }
            raw = string
        } else if let object = value.objectValue {
            if let rawScale = object["scale"]?.stringValue {
                guard
                    rawScale.utf8.count <= 3,
                    let scale = Int(rawScale),
                    (0 ... NexusAmountPolicy.maximumScale).contains(scale),
                    let mantissa = ["value", "amount", "mantissa"]
                        .lazy
                        .compactMap({ object[$0]?.exactWireStringValue })
                        .first,
                    mantissa.utf8.count <=
                        PIQuantity.maximumWireBytes,
                    mantissa.range(
                        of: #"^[0-9]+$"#,
                        options: .regularExpression
                    ) != nil
                else {
                    throw NexusToriiError.invalidResponse
                }
                raw = decimalString(mantissa: mantissa, scale: scale)
            } else if let nested = ["value", "amount", "mantissa"]
                .lazy
                .compactMap({ object[$0] })
                .first {
                return try parseAmount(nested)
            } else {
                raw = nil
            }
        } else {
            raw = nil
        }
        guard
            let raw,
            raw.utf8.count <= PIQuantity.maximumWireBytes,
            raw.range(
                of: #"^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$"#,
                options: .regularExpression
            ) != nil,
            let exact = NexusExactDecimal(raw),
            exact.unscaled > 0
        else {
            throw NexusToriiError.invalidResponse
        }
        return try PIQuantity(raw)
    }

    private static func decimalString(mantissa: String, scale: Int) -> String {
        let trimmed = String(mantissa.drop { $0 == "0" })
        let digits = trimmed.isEmpty ? "0" : trimmed
        guard scale > 0 else {
            return digits
        }
        let padded = String(repeating: "0", count: max(0, scale - digits.count + 1)) +
            digits
        let split = padded.index(padded.endIndex, offsetBy: -scale)
        let integer = String(padded[..<split])
        var fraction = String(padded[split...])
        while fraction.last == "0" {
            fraction.removeLast()
        }
        return fraction.isEmpty ? integer : "\(integer).\(fraction)"
    }

    private static func firstString(
        in object: [String: NexusJSONValue],
        keys: [String]
    ) -> String? {
        keys.lazy.compactMap { object[$0]?.stringValue }
            .first(where: { !$0.isEmpty })
    }

    private static func normalizedHash(_ value: String) -> String? {
        NexusTransactionHash.normalized(value)
    }

    private static func timestampMilliseconds(_ value: String) -> Int64? {
        if value.allSatisfy(\.isNumber), let raw = Int64(value) {
            guard raw >= 0 else {
                return nil
            }
            if raw < millisecondThreshold {
                return raw.multipliedReportingOverflow(by: 1_000).overflow
                    ? nil
                    : raw * 1_000
            }
            return raw
        }
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractions = ISO8601DateFormatter()
        withoutFractions.formatOptions = [.withInternetDateTime]
        guard let date = withFractions.date(from: value) ?? withoutFractions.date(from: value) else {
            return nil
        }
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds >= 0, milliseconds <= Double(Int64.max) else {
            return nil
        }
        return Int64(milliseconds)
    }
}

struct NexusTransactionReceipt: Decodable, Equatable {
    struct Payload: Decodable, Equatable {
        let txHash: String
        let entrypointHash: String
        let signedTransactionHash: String?
        let submittedAtMs: Int64
        let submittedAtHeight: Int64

        private enum CodingKeys: String, CodingKey {
            case txHash = "tx_hash"
            case entrypointHash = "entrypoint_hash"
            case signedTransactionHash = "signed_transaction_hash"
            case submittedAtMs = "submitted_at_ms"
            case submittedAtHeight = "submitted_at_height"
        }
    }

    let payload: Payload

    func validate(expectedHash: String) throws {
        guard let canonicalExpectedHash = NexusTransactionHash.normalized(
            expectedHash
        ) else {
            throw NexusToriiError.invalidResponse
        }
        guard
            NexusTransactionHash.normalized(payload.txHash) ==
                canonicalExpectedHash,
            NexusTransactionHash.normalized(payload.entrypointHash) ==
                canonicalExpectedHash
        else {
            throw NexusToriiError.transactionHashMismatch
        }
        if let signedTransactionHash = payload.signedTransactionHash {
            guard
                NexusTransactionHash.normalized(signedTransactionHash) ==
                    canonicalExpectedHash
            else {
                throw NexusToriiError.transactionHashMismatch
            }
        }
        guard
            payload.submittedAtMs > 0,
            payload.submittedAtHeight >= 0
        else {
            throw NexusToriiError.invalidResponse
        }
    }
}

struct NexusPipelineStatus: Decodable, Equatable {
    struct Status: Decodable, Equatable {
        let kind: String
        let content: String?
        let rejectionReason: NexusJSONValue?
        let blockHeight: Int64?

        private enum CodingKeys: String, CodingKey {
            case kind
            case content
            case rejectionReason = "rejection_reason"
            case blockHeight = "block_height"
        }
    }

    let hash: String
    let status: Status
    let scope: String
    let resolvedFrom: String

    var hasAuthoritativeGlobalResolution: Bool {
        guard scope == "global" else {
            return false
        }
        let canonicalKind = status.kind.lowercased()
        switch canonicalKind {
        case "applied":
            // Applied is authoritative only when Torii resolved it from chain
            // state and bound it to a positive block. A cached observation can
            // be stale and must remain recoverable rather than becoming final.
            return resolvedFrom == "state" &&
                status.blockHeight.map({ $0 > 0 }) == true &&
                status.rejectionReason == nil
        case "rejected", "expired":
            // A cached terminal failure can race a live transaction. Persist it
            // as terminal only after Torii resolves the global state record.
            return resolvedFrom == "state"
        case "committed":
            return ["queue", "cache", "state"].contains(resolvedFrom) &&
                status.blockHeight.map({ $0 > 0 }) == true &&
                status.rejectionReason == nil
        case "queued", "submitted", "approved":
            return ["queue", "cache", "state"].contains(resolvedFrom)
        default:
            return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case hash
        case status
        case scope
        case resolvedFrom = "resolved_from"
    }
}

private final class NexusRedirectRejectingDelegate: NSObject,
    URLSessionTaskDelegate
{
    static let shared = NexusRedirectRejectingDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class NexusToriiClient {
    private struct ErrorEnvelope: Decodable {
        let message: String
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let responseLimit = 2 * 1024 * 1024
    private static let maximumFanoutRoutes = 1_024
    private static let routedByHeader = "x-iroha-routed-by"
    private static let routeLaneIDHeader = "x-iroha-route-lane-id"
    private static let routeDataspaceIDHeader = "x-iroha-route-dataspace-id"
    private static let fanoutCountHeaders = [
        "x-iroha-fanout-routes-attempted",
        "x-iroha-fanout-routes-succeeded",
        "x-iroha-fanout-routes-failed",
        "x-iroha-fanout-routes-unavailable",
        "x-iroha-fanout-routes-denied",
        "x-iroha-fanout-routes-not-found"
    ]

    static func responseAcceptHeader(for url: URL) -> String {
        url.path.hasSuffix("/health") ? "text/plain" : "application/json"
    }

    static func requestContentType(
        method: String,
        for url: URL
    ) throws -> String? {
        switch (method, url.path) {
        case ("GET", _):
            return nil
        case ("POST", let path) where path.hasSuffix("/v1/mcp"):
            return "application/json"
        case ("POST", let path)
            where path.hasSuffix("/v1/pipeline/transactions"):
            return "application/x-norito"
        default:
            throw NexusToriiError.invalidRoute
        }
    }

    /// A successful Torii response must honor the representation requested for its exact route.
    /// Accept only the bare media type or its single standard UTF-8 charset parameter; missing,
    /// combined, or profiled values fail closed before any response body is trusted.
    static func isExpectedResponseContentType(
        _ value: String?,
        for url: URL
    ) -> Bool {
        NexusToriiMediaTypeContract.matches(
            value,
            expected: responseAcceptHeader(for: url)
        )
    }

    static func xorAssetDefinitionURL(
        configuration: NexusNetworkConfiguration
    ) -> URL {
        configuration.toriiURL
            .appendingPathComponent("v1/assets/definitions")
            .appendingPathComponent(NexusAssetDefinitionIdentity.xorAlias)
    }

    static func validateHealthPayload(_ data: Data) throws {
        guard data == Data("Healthy".utf8) else {
            throw NexusToriiError.invalidResponse
        }
    }

    static func validateResponseLength(
        _ expectedContentLength: Int64,
        maximumBytes: Int
    ) throws {
        guard
            maximumBytes >= 0,
            expectedContentLength < 0 ||
                expectedContentLength <= Int64(maximumBytes)
        else {
            throw NexusToriiError.responseTooLarge
        }
    }

    static func appendResponseByte(
        _ byte: UInt8,
        to data: inout Data,
        maximumBytes: Int
    ) throws {
        guard maximumBytes >= 0, data.count < maximumBytes else {
            throw NexusToriiError.responseTooLarge
        }
        data.append(byte)
    }

    /// A 2xx proxy response is authoritative only when its declared fanout completed in full.
    static func validateFanoutHeaders(
        _ response: HTTPURLResponse,
        requiresFanout: Bool = false
    ) throws {
        try validateFanoutHeaderValues(
            { response.value(forHTTPHeaderField: $0) },
            requiresFanout: requiresFanout
        )
    }

    static func validateFanoutHeaderValues(
        _ headerValue: (String) -> String?,
        requiresFanout: Bool = false
    ) throws {
        let firstFailure = headerValue("x-iroha-fanout-first-failure")
        let routedBy = headerValue(routedByHeader)
        let routeLaneID = headerValue(routeLaneIDHeader)
        let routeDataspaceID = headerValue(routeDataspaceIDHeader)
        guard
            routedBy.map({ ["local", "proxy"].contains($0) }) ?? true,
            (routeLaneID == nil) == (routeDataspaceID == nil),
            routeLaneID == nil || routedBy != nil,
            routeLaneID.map({
                isCanonicalRouteID($0, maximum: UInt64(UInt32.max))
            }) ?? true,
            routeDataspaceID.map({
                isCanonicalRouteID($0, maximum: UInt64.max)
            }) ?? true
        else {
            throw NexusToriiError.invalidResponse
        }
        let rawCounts = fanoutCountHeaders.map {
            headerValue($0)
        }
        if rawCounts.allSatisfy({ $0 == nil }) {
            guard firstFailure == nil, !requiresFanout else {
                throw NexusToriiError.invalidResponse
            }
            return
        }
        guard
            firstFailure == nil,
            rawCounts.allSatisfy({ $0 != nil }),
            routedBy != nil,
            routeLaneID == nil,
            routeDataspaceID == nil
        else {
            throw NexusToriiError.invalidResponse
        }
        let counts = try rawCounts.map { raw -> Int in
            guard
                let raw,
                raw.range(
                    of: #"^(?:0|[1-9][0-9]{0,3})$"#,
                    options: .regularExpression
                ) != nil,
                let count = Int(raw),
                count <= maximumFanoutRoutes
            else {
                throw NexusToriiError.invalidResponse
            }
            return count
        }
        guard
            counts[0] > 0,
            counts[1] == counts[0],
            counts.dropFirst(2).allSatisfy({ $0 == 0 })
        else {
            throw NexusToriiError.invalidResponse
        }
    }

    private static func isCanonicalRouteID(
        _ value: String,
        maximum: UInt64
    ) -> Bool {
        guard
            !value.isEmpty,
            value.utf8.count <= 20,
            value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
            value == "0" || !value.hasPrefix("0"),
            let parsed = UInt64(value)
        else {
            return false
        }
        return parsed <= maximum
    }

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = true
            configuration.httpMaximumConnectionsPerHost = 2
            self.session = URLSession(
                configuration: configuration,
                delegate: NexusRedirectRejectingDelegate.shared,
                delegateQueue: nil
            )
        }
    }

    func health(configuration: NexusNetworkConfiguration) async throws {
        let payload = try await data(
            request: request(
                url: configuration.toriiURL.appendingPathComponent("health"),
                method: "GET"
            )
        )
        try Self.validateHealthPayload(payload)
    }

    func xorAssetDefinition(
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusAssetDefinition {
        let definition = try decoder.decode(
            NexusAssetDefinition.self,
            from: await data(
                request: request(
                    url: Self.xorAssetDefinitionURL(
                        configuration: configuration
                    ),
                    method: "GET"
                ),
                requiresFanout: true
            )
        )
        try NexusAssetDefinitionIdentity.validateXor(definition)
        return definition
    }

    func accountAssets(
        account: String,
        configuration: NexusNetworkConfiguration,
        asset: String,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> NexusAccountAssetList {
        try configuration.validate(address: account)
        guard (1 ... 500).contains(limit), offset >= 0 else {
            throw NexusToriiError.invalidRoute
        }

        var components = URLComponents(
            url: configuration.toriiURL
                .appendingPathComponent("v1/accounts")
                .appendingPathComponent(account)
                .appendingPathComponent("assets"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "count_mode", value: "exact"),
            URLQueryItem(name: "asset", value: asset),
            URLQueryItem(name: "scope", value: "global")
        ]
        guard let url = components?.url else {
            throw NexusToriiError.invalidRoute
        }
        return try decoder.decode(
            NexusAccountAssetList.self,
            from: await data(
                request: request(url: url, method: "GET"),
                requiresFanout: true
            )
        )
    }

    func accountTransactions(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> NexusAccountTransactionList {
        let url = try Self.accountTransactionsURL(
            account: account,
            configuration: configuration,
            assetDefinitionID: assetDefinitionID,
            limit: limit,
            offset: offset
        )
        return try decoder.decode(
            NexusAccountTransactionList.self,
            from: await data(
                request: request(url: url, method: "GET"),
                requiresFanout: true
            )
        )
    }

    static func accountTransactionsURL(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        limit: Int = 50,
        offset: Int = 0
    ) throws -> URL {
        try configuration.validate(address: account)
        guard
            (1 ... 100).contains(limit),
            offset >= 0,
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                assetDefinitionID
            )
        else {
            throw NexusToriiError.invalidRoute
        }
        var components = URLComponents(
            url: configuration.toriiURL
                .appendingPathComponent("v1/accounts")
                .appendingPathComponent(account)
                .appendingPathComponent("transactions"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "asset_id", value: assetDefinitionID),
            URLQueryItem(name: "count_mode", value: "exact")
        ]
        guard let url = components?.url else {
            throw NexusToriiError.invalidRoute
        }
        return url
    }

    /// Requires an exact, complete-fanout account-history proof for the
    /// committed entrypoint hash. The server orders committed transactions
    /// newest-first; bounded pagination still rejects count drift, duplicate
    /// hashes, and repeated pages instead of treating an incomplete scan as
    /// authoritative absence.
    func hasAuthoritativeCommittedTransaction(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        transactionHash: String
    ) async throws -> Bool {
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        guard
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                assetDefinitionID
            ),
            let expectedHash = NexusTransactionHash.normalized(
                transactionHash
            )
        else {
            throw NexusToriiError.invalidRoute
        }

        var proof = try NexusAccountTransactionProof(
            account: canonicalAccount,
            configuration: configuration,
            transactionHash: expectedHash
        )
        while true {
            let page = try await accountTransactions(
                account: canonicalAccount,
                configuration: configuration,
                assetDefinitionID: assetDefinitionID,
                limit: 100,
                offset: proof.nextOffset
            )
            switch try proof.accept(page) {
            case .found:
                return true
            case .absent:
                return false
            case .continueScanning:
                continue
            }
        }
    }

    /// Reads committed transfer instructions through Torii's curated MCP
    /// surface. Pagination is bounded and repeated pages are rejected so a
    /// malformed server cannot keep a wallet refresh alive indefinitely.
    func committedXorTransfers(
        account: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> [NexusTransferHistoryItem] {
        let definition = try await xorAssetDefinition(
            configuration: configuration
        )
        return try await committedXorTransfers(
            account: account,
            configuration: configuration,
            assetDefinitionID: definition.id
        )
    }

    func committedXorTransfers(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) async throws -> [NexusTransferHistoryItem] {
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        guard
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                assetDefinitionID
            )
        else {
            throw NexusToriiError.invalidRoute
        }

        let pageSize = 50
        let maximumPages = 20
        var history: [NexusTransferHistoryItem] = []
        var fingerprints = Set<String>()
        for page in 1 ... maximumPages {
            let response = try await mcp(
                NexusMCPRequest(
                    id: "history-\(page)",
                    params: .object([
                        "name": .string("iroha.instructions.list"),
                        "arguments": .object([
                            "account": .string(canonicalAccount),
                            "asset_id": .string(assetDefinitionID),
                            "kind": .string("Transfer"),
                            "page": .number(String(page)),
                            "per_page": .number(String(pageSize)),
                            "transaction_status": .string("committed"),
                            "accept": .string("application/json")
                        ])
                    ])
                ),
                configuration: configuration
            )
            guard response.error == nil, let result = response.result else {
                throw NexusToriiError.server
            }
            let structuredResult = try NexusMCPResultContract
                .validateEmbeddedRoute(
                    result,
                    requiresFanout: true
                )
            let parsed = try NexusTransferHistoryParser.page(
                result: structuredResult,
                configuration: configuration,
                account: canonicalAccount,
                assetDefinitionID: assetDefinitionID
            )
            guard parsed.sourceItemCount <= pageSize else {
                throw NexusToriiError.invalidResponse
            }
            if parsed.sourceItemCount > 0 {
                let fingerprint = parsed.items.map {
                    "\($0.transactionHash):\($0.amount.rawValue):\($0.sender):\($0.receiver)"
                }.joined(separator: "|")
                guard fingerprints.insert(fingerprint).inserted else {
                    throw NexusToriiError.invalidResponse
                }
            }
            history.append(contentsOf: parsed.items)
            if parsed.sourceItemCount < pageSize {
                return history
            }
        }
        throw NexusToriiError.invalidResponse
    }

    func submit(
        signedNorito: Data,
        idempotencyKey: UUID,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusTransactionReceipt {
        var transactionRequest = request(
            url: configuration.toriiURL
                .appendingPathComponent("v1/pipeline/transactions"),
            method: "POST"
        )
        transactionRequest.httpBody = signedNorito
        transactionRequest.setValue(
            "application/x-norito",
            forHTTPHeaderField: "Content-Type"
        )
        transactionRequest.setValue(
            idempotencyKey.uuidString,
            forHTTPHeaderField: "Idempotency-Key"
        )
        return try decoder.decode(
            NexusTransactionReceipt.self,
            from: await data(request: transactionRequest)
        )
    }

    func status(
        hash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusPipelineStatus {
        guard let normalizedHash = NexusTransactionHash.normalized(hash) else {
            throw NexusToriiError.invalidRoute
        }
        var components = URLComponents(
            url: configuration.toriiURL
                .appendingPathComponent("v1/pipeline/transactions/status"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "hash", value: normalizedHash),
            URLQueryItem(name: "scope", value: "global")
        ]
        guard let url = components?.url else {
            throw NexusToriiError.invalidRoute
        }
        return try decoder.decode(
            NexusPipelineStatus.self,
            from: await data(request: request(url: url, method: "GET"))
        )
    }

    private func mcp(
        _ payload: NexusMCPRequest,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusMCPResponse {
        guard
            payload.id.range(
                of: #"^[A-Za-z0-9._:-]{1,64}$"#,
                options: .regularExpression
            ) != nil
        else {
            throw NexusToriiError.invalidRoute
        }
        var mcpRequest = request(
            url: configuration.toriiURL
                .appendingPathComponent("v1/mcp"),
            method: "POST"
        )
        mcpRequest.httpBody = try encoder.encode(payload)
        mcpRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        let response = try decoder.decode(
            NexusMCPResponse.self,
            from: await data(request: mcpRequest)
        )
        try NexusMCPEnvelopeContract.validate(
            jsonrpc: response.jsonrpc,
            responseID: response.id,
            expectedID: payload.id,
            hasError: response.error != nil
        )
        return response
    }

    private func request(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            Self.responseAcceptHeader(for: url),
            forHTTPHeaderField: "Accept"
        )
        return request
    }

    private func data(
        request: URLRequest,
        requiresFanout: Bool = false
    ) async throws -> Data {
        guard let requestURL = request.url, let method = request.httpMethod else {
            throw NexusToriiError.invalidRoute
        }
        // The external deployment admission is the only authority for Taira
        // transport. In particular the convenience hostname is never a
        // fallback. This guard executes before URLSession observes a request.
        guard NexusNetworkConfiguration.transportIsAdmitted(
            for: requestURL
        ) else {
            throw NexusToriiError.invalidRoute
        }
        let expectedRequestContentType = try Self.requestContentType(
            method: method,
            for: requestURL
        )
        let requestHasBody = request.httpBody != nil || request.httpBodyStream != nil
        guard
            request.value(forHTTPHeaderField: "Content-Type")
                == expectedRequestContentType,
            requestHasBody == (expectedRequestContentType != nil)
        else {
            throw NexusToriiError.invalidRoute
        }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NexusToriiError.invalidResponse
        }
        guard response.url == requestURL else {
            throw NexusToriiError.invalidRoute
        }
        try Self.validateResponseLength(
            response.expectedContentLength,
            maximumBytes: responseLimit
        )
        let isSuccessful = (200 ... 299).contains(response.statusCode)
        if isSuccessful {
            guard
                Self.isExpectedResponseContentType(
                    response.value(forHTTPHeaderField: "Content-Type"),
                    for: requestURL
                )
            else {
                throw NexusToriiError.invalidResponse
            }
            try Self.validateFanoutHeaders(
                response,
                requiresFanout: requiresFanout
            )
        }
        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        for try await byte in bytes {
            try Self.appendResponseByte(
                byte,
                to: &data,
                maximumBytes: responseLimit
            )
        }
        guard isSuccessful else {
            if (try? decoder.decode(ErrorEnvelope.self, from: data)) != nil {
                throw NexusToriiError.server
            }
            throw NexusToriiError.httpStatus(response.statusCode)
        }
        return data
    }

}

/// The restart reconciler receives only this read-only Torii surface. Keeping
/// submission in a disjoint protocol prevents a status/history recovery path
/// from compiling a transaction POST through its client dependency.
protocol NexusToriiReading {
    func xorAssetDefinition(
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusAssetDefinition

    func accountAssets(
        account: String,
        configuration: NexusNetworkConfiguration,
        asset: String,
        limit: Int,
        offset: Int
    ) async throws -> NexusAccountAssetList

    func status(
        hash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusPipelineStatus

    func hasAuthoritativeCommittedTransaction(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        transactionHash: String
    ) async throws -> Bool

    func committedXorTransfers(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) async throws -> [NexusTransferHistoryItem]
}

protocol NexusToriiSubmitting {
    func submit(
        signedNorito: Data,
        idempotencyKey: UUID,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusTransactionReceipt
}

final class NexusToriiReadClient: NexusToriiReading {
    private let transport: NexusToriiClient

    init(transport: NexusToriiClient = NexusToriiClient()) {
        self.transport = transport
    }

    func xorAssetDefinition(
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusAssetDefinition {
        try await transport.xorAssetDefinition(configuration: configuration)
    }

    func accountAssets(
        account: String,
        configuration: NexusNetworkConfiguration,
        asset: String,
        limit: Int,
        offset: Int
    ) async throws -> NexusAccountAssetList {
        try await transport.accountAssets(
            account: account,
            configuration: configuration,
            asset: asset,
            limit: limit,
            offset: offset
        )
    }

    func status(
        hash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusPipelineStatus {
        try await transport.status(
            hash: hash,
            configuration: configuration
        )
    }

    func hasAuthoritativeCommittedTransaction(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        transactionHash: String
    ) async throws -> Bool {
        try await transport.hasAuthoritativeCommittedTransaction(
            account: account,
            configuration: configuration,
            assetDefinitionID: assetDefinitionID,
            transactionHash: transactionHash
        )
    }

    func committedXorTransfers(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) async throws -> [NexusTransferHistoryItem] {
        try await transport.committedXorTransfers(
            account: account,
            configuration: configuration,
            assetDefinitionID: assetDefinitionID
        )
    }
}

final class NexusToriiSubmissionClient: NexusToriiSubmitting {
    private let transport: NexusToriiClient

    init(transport: NexusToriiClient = NexusToriiClient()) {
        self.transport = transport
    }

    func submit(
        signedNorito: Data,
        idempotencyKey: UUID,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusTransactionReceipt {
        try await transport.submit(
            signedNorito: signedNorito,
            idempotencyKey: idempotencyKey,
            configuration: configuration
        )
    }
}

struct NexusTransferRequest: Equatable {
    let walletId: String
    let networkId: NetworkId
    let sender: String
    let receiver: String
    let amount: PIQuantity
}

struct NexusCurrentXorBalance: Equatable {
    let quantity: PIQuantity
    let assetDefinitionID: String
}

struct NexusTransferFeeQuote: Equatable {
    let networkId: NetworkId
    let authority: String
    let receiver: String
    let assetDefinitionId: String
    let amount: PIQuantity
    let fee: PIQuantity
    let quoteIdentity: String
    let validUntilBlock: Int64?
}

final class NexusPreparedTransfer: Equatable {
    let request: NexusTransferRequest
    let canonicalReceiver: String
    let assetDefinitionID: String
    let availableBalance: PIQuantity
    let quote: NexusTransferFeeQuote

    private let submissionLock = NSLock()
    private var submissionStarted = false

    init(
        request: NexusTransferRequest,
        canonicalReceiver: String,
        assetDefinitionID: String,
        availableBalance: PIQuantity,
        quote: NexusTransferFeeQuote
    ) {
        self.request = request
        self.canonicalReceiver = canonicalReceiver
        self.assetDefinitionID = assetDefinitionID
        self.availableBalance = availableBalance
        self.quote = quote
    }

    func reserveSubmission() -> Bool {
        submissionLock.lock()
        defer { submissionLock.unlock() }
        guard !submissionStarted else {
            return false
        }
        submissionStarted = true
        return true
    }

    static func == (
        lhs: NexusPreparedTransfer,
        rhs: NexusPreparedTransfer
    ) -> Bool {
        lhs === rhs ||
            (
                lhs.request == rhs.request &&
                    lhs.canonicalReceiver == rhs.canonicalReceiver &&
                    lhs.assetDefinitionID == rhs.assetDefinitionID &&
                    lhs.availableBalance == rhs.availableBalance &&
                    lhs.quote == rhs.quote
            )
    }
}

struct NexusSignedTransaction: Equatable {
    /// Exact Norito bytes produced by the reviewed native bridge.
    var payload: Data
    /// Canonical pipeline hash derived locally by that same bridge before any
    /// network I/O. Persisting it before submission makes a timeout
    /// reconcilable after restart without ever resubmitting the transaction.
    let pipelineHash: String
}

/// Read-only finalized checkpoint returned by the reviewed network adapter.
/// A height without the exact selected network, configured chain UUID, and
/// canonical nonzero finalized block hash is not authoritative enough to
/// expire a quote or reconcile a transaction.
/// A qualified native verifier must decode Torii's checksummed Norito hash
/// literal and project the verified 32 bytes as the shared Android/iOS
/// lowercase, prefix-free 64-hex representation used here.
struct NexusFinalityCheckpoint: Equatable {
    let networkId: NetworkId
    let chainId: UUID
    let finalizedBlockHeight: Int64
    let finalizedBlockHash: String

    func requireHeight(
        for configuration: NexusNetworkConfiguration
    ) throws -> Int64 {
        guard
            networkId == configuration.networkId,
            chainId == configuration.chainId,
            finalizedBlockHeight > 0,
            NexusTransactionHash.normalized(finalizedBlockHash) ==
                finalizedBlockHash
        else {
            throw NexusToriiError.invalidResponse
        }
        return finalizedBlockHeight
    }
}

/// Read-only finalized-head dependency shared by quote expiry and restart
/// reconciliation. Keeping it separate from `NexusTransactionSigning` makes
/// it impossible for recovery to reach quote or secret-signing capability.
protocol NexusFinalityReading {
    /// May return true only when the exact network has reviewed node,
    /// signed-genesis, and first-context trust anchors plus a provenance-bound
    /// native verifier for challenge-bound BridgeFinalityAttestationV1 and
    /// bounded sequential BridgeFinalityBundle catch-up. Scalar status height
    /// and response-declared identity are never qualification evidence.
    func isQualified(
        for configuration: NexusNetworkConfiguration
    ) -> Bool

    /// Returns a response-bound checkpoint for the exact selected network.
    /// Qualified implementations must not copy caller identity into an
    /// otherwise unbound response or silently fall back to another network.
    func finalizedCheckpoint(
        for configuration: NexusNetworkConfiguration
    ) async throws -> NexusFinalityCheckpoint
}

protocol NexusTransactionSigning {
    func isQualified(
        for configuration: NexusNetworkConfiguration
    ) -> Bool

    /// Qualified implementations must fully parse the opaque ID, including
    /// its BLAKE3 checksum, and return a quote for that exact definition.
    func quoteTransfer(
        _ request: NexusTransferRequest,
        assetDefinitionID: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusTransferFeeQuote

    /// The bridge must reject any mismatch between this exact definition ID,
    /// the reviewed quote, and the encoded Norito transfer instruction.
    func signTransfer(
        _ request: NexusTransferRequest,
        assetDefinitionID: String,
        quote: NexusTransferFeeQuote,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusSignedTransaction
}

/// Release builds fail closed until the reviewed, checksum-pinned
/// NoritoBridge.xcframework is present. No JSON/MCP private-key fallback is
/// permitted.
struct UnavailableNexusTransactionSigner: NexusTransactionSigning {
    func isQualified(
        for configuration: NexusNetworkConfiguration
    ) -> Bool {
        false
    }

    func quoteTransfer(
        _ request: NexusTransferRequest,
        assetDefinitionID: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusTransferFeeQuote {
        throw NexusToriiError.nativeBridgeUnavailable
    }

    func signTransfer(
        _ request: NexusTransferRequest,
        assetDefinitionID: String,
        quote: NexusTransferFeeQuote,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusSignedTransaction {
        throw NexusToriiError.nativeBridgeUnavailable
    }
}

/// Finality also remains disabled until the reviewed network-scoped native
/// adapter is installed. This dependency contains no quoting or signing API,
/// so startup recovery cannot accidentally request secret-key work.
struct UnavailableNexusFinalityReader: NexusFinalityReading {
    func isQualified(
        for configuration: NexusNetworkConfiguration
    ) -> Bool {
        false
    }

    func finalizedCheckpoint(
        for configuration: NexusNetworkConfiguration
    ) async throws -> NexusFinalityCheckpoint {
        throw NexusToriiError.finalizedHeadUnavailable
    }
}

enum NexusPendingState: String, Codable {
    case signing
    case failedBeforeSubmission
    case submitting
    case submissionUnknown
    case submitted
    case approved
    case committedPendingReconciliation
    case committed
    case rejected
    case expired

    var isTerminal: Bool {
        [.failedBeforeSubmission, .committed, .rejected, .expired].contains(self)
    }
}

enum NexusPendingRecoveryPolicy {
    static func shouldFailAsInterruptedPreSubmission(
        state: NexusPendingState,
        hash: String?,
        ownedByLiveSubmission: Bool
    ) -> Bool {
        !ownedByLiveSubmission && state == .signing && hash == nil
    }
}

/// Epoch binding for new Taira journal rows. UUID alone is deliberately
/// insufficient: either known UUID may be selected by a later signed manifest,
/// and that must not make an older schema-77 row authoritative again.
struct NexusPendingTairaDeploymentIdentity: Codable, Equatable {
    let manifestSha256: String
    let deploymentEpoch: UInt64
    let genesisHash: String

    static func admitted(
        for configuration: NexusNetworkConfiguration,
        deployment: TairaDeploymentBinding? =
            TairaDeploymentBinding.admittedFromBundle
    ) -> NexusPendingTairaDeploymentIdentity? {
        guard configuration.networkId == .taira else {
            return nil
        }
        guard
            let binding = deployment,
            binding.currentChainId == configuration.chainId
        else {
            return nil
        }
        return NexusPendingTairaDeploymentIdentity(
            manifestSha256: binding.manifestSha256,
            deploymentEpoch: binding.currentDeploymentEpoch,
            genesisHash: binding.currentGenesisHash
        )
    }

    var hasCanonicalShape: Bool {
        deploymentEpoch > 0 &&
            manifestSha256 != String(repeating: "0", count: 64) &&
            genesisHash != String(repeating: "0", count: 64) &&
            manifestSha256.range(
                of: "^[0-9a-f]{64}$",
                options: .regularExpression
            ) != nil &&
            genesisHash.range(
                of: "^[0-9a-f]{64}$",
                options: .regularExpression
            ) != nil
    }
}

struct NexusPendingTransaction: Codable, Equatable, Identifiable {
    let id: UUID
    let idempotencyKey: UUID
    let walletId: String
    let networkId: NetworkId
    /// Exact chain UUID used to construct and sign this transaction. Nil is
    /// accepted only as read-only legacy evidence. A non-current UUID is also
    /// retained read-only because a testnet reset may keep the same networkId
    /// and I105 discriminant while replacing the chain.
    let chainId: UUID?
    /// Missing on legacy schema-77 rows. Such rows stay recovery-only even if
    /// a future admitted deployment selects the same chain UUID again.
    var tairaDeployment: NexusPendingTairaDeploymentIdentity? = nil
    /// Internal-TestFlight rows carry only the exact unsigned convenience
    /// configuration digest. Production rows leave this nil. A production app
    /// can retain such rows as recovery evidence but can never resume them.
    var internalTairaConfigurationSha256: String? = nil
    let sender: String
    let receiver: String
    /// Exact opaque definition selected by `xor#universal` when the signed
    /// transaction was prepared. Nil is retained only so journals written by
    /// the prior production version remain readable and recovery-safe.
    let assetDefinitionID: String?
    let amount: PIQuantity
    let fee: PIQuantity
    let createdAt: Date
    var updatedAt: Date
    var hash: String?
    var state: NexusPendingState
    var terminalBlockHeight: Int64?
    var errorClass: String?
    var historyReconciledAt: Date?

    var requiresCommittedHistoryReconciliation: Bool {
        state == .committed && historyReconciledAt == nil
    }

    static func currentInternalTairaConfigurationSha256(
        for configuration: NexusNetworkConfiguration
    ) -> String? {
#if SORA_INTERNAL_TAIRA_TESTFLIGHT
        guard
            TairaDeploymentBinding.admittedFromBundle == nil,
            let binding =
                InternalTairaTestFlightBinding.resolvedFromBundle
        else {
            return nil
        }
        return internalTairaConfigurationSha256(
            for: configuration,
            binding: binding
        )
#else
        return nil
#endif
    }

#if SORA_INTERNAL_TAIRA_TESTFLIGHT
    static func internalTairaConfigurationSha256(
        for configuration: NexusNetworkConfiguration,
        binding _: InternalTairaTestFlightBinding
    ) -> String? {
        guard
            configuration.networkId == .taira,
            configuration.chainId ==
                InternalTairaTestFlightBinding.currentChainId
        else {
            return nil
        }
        return InternalTairaTestFlightBinding.configurationSha256
    }

    func hasCurrentInternalTairaDeploymentIdentity(
        for configuration: NexusNetworkConfiguration,
        binding: InternalTairaTestFlightBinding
    ) -> Bool {
        tairaDeployment == nil &&
            internalTairaConfigurationSha256 ==
                Self.internalTairaConfigurationSha256(
                    for: configuration,
                    binding: binding
                )
    }
#endif

    func hasCurrentDeploymentIdentity(
        for configuration: NexusNetworkConfiguration,
        tairaBinding: TairaDeploymentBinding? =
            TairaDeploymentBinding.admittedFromBundle
    ) -> Bool {
        guard chainId == configuration.chainId else {
            return false
        }
        switch configuration.networkId {
        case .taira:
            if let expected = NexusPendingTairaDeploymentIdentity.admitted(
                for: configuration,
                deployment: tairaBinding
            ) {
                return internalTairaConfigurationSha256 == nil &&
                    tairaDeployment == expected
            }
#if SORA_INTERNAL_TAIRA_TESTFLIGHT
            guard
                let binding =
                    InternalTairaTestFlightBinding.resolvedFromBundle
            else {
                return false
            }
            return hasCurrentInternalTairaDeploymentIdentity(
                for: configuration,
                binding: binding
            )
#else
            return false
#endif
        case .minamoto:
            return tairaDeployment == nil &&
                internalTairaConfigurationSha256 == nil
        case .sora2:
            return false
        }
    }
}

/// Nexus, Polkamarkt, and the SORA2 one-shot submission journal intentionally
/// share one bounded namespace. A process can terminate after a crash-durable
/// temporary file
/// is synced but before it is renamed over the canonical journal. Treat any
/// such orphan (or any other unexpected entry) as unresolved evidence rather
/// than interpreting a missing canonical file as an empty transaction set.
enum PendingTransactionJournalNamespace {
    enum Failure: Error {
        case invalidNamespace
    }

    private static let allowedJournalNames: Set<String> = [
        "nexus-v1.json",
        "polkamarkt-v1.json",
        "sora2-signed-v1.json",
    ]
    private static let maximumJournalBytes = 2 * 1_024 * 1_024
    private static let maximumNamespaceBytes =
        allowedJournalNames.count * maximumJournalBytes

    static func validate(
        directoryURL: URL,
        fileManager: FileManager
    ) throws {
        let directoryValues = try directoryURL.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard
            directoryValues.isDirectory == true,
            directoryValues.isSymbolicLink != true
        else {
            throw Failure.invalidNamespace
        }

        let entries = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        guard entries.count <= allowedJournalNames.count else {
            throw Failure.invalidNamespace
        }

        var remainingBytes = maximumNamespaceBytes
        for entry in entries {
            let values = try entry.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                allowedJournalNames.contains(entry.lastPathComponent),
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let fileSize = values.fileSize,
                fileSize >= 0,
                fileSize <= maximumJournalBytes,
                fileSize <= remainingBytes
            else {
                throw Failure.invalidNamespace
            }
            remainingBytes -= fileSize
        }
    }
}

actor NexusPendingTransactionStore {
    private static let maximumJournalBytes = 2 * 1_024 * 1_024
    private static let maximumTransactions = 500

    private let directoryURL: URL
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, baseURL: URL? = nil) throws {
        self.fileManager = fileManager
        let base: URL
        if let baseURL {
            base = baseURL
        } else {
            base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        directoryURL = base
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        fileURL = directoryURL.appendingPathComponent("nexus-v1.json")
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func all() throws -> [NexusPendingTransaction] {
        do {
            try PendingTransactionJournalNamespace.validate(
                directoryURL: directoryURL,
                fileManager: fileManager
            )
        } catch {
            throw NexusToriiError.invalidResponse
        }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        // DurableFileWriter publishes by renaming a new inode over this path.
        // Never reuse resource values cached on the URL from the prior inode,
        // or a legitimate size change can be misclassified as journal damage.
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
            throw NexusToriiError.invalidResponse
        }
        let data = try Data(contentsOf: currentFileURL)
        guard
            data.count == fileSize,
            data.count <= Self.maximumJournalBytes
        else {
            throw NexusToriiError.invalidResponse
        }
        let transactions = try decoder.decode(
            [NexusPendingTransaction].self,
            from: data
        )
        guard
            transactions.count <= Self.maximumTransactions,
            Set(transactions.map(\.id)).count == transactions.count,
            Set(transactions.map(\.idempotencyKey)).count == transactions.count
        else {
            throw NexusToriiError.invalidResponse
        }
        try transactions.forEach {
            try validate($0, allowsReadOnlyHistoricalChain: true)
        }
        let transactionHashes = transactions.compactMap {
            Self.transactionHashIdentity(for: $0)
        }
        let transactionHashScopes = transactions.compactMap {
            Self.transactionHashScope(for: $0)
        }
        let unboundHashScopes = transactions
            .filter { $0.chainId == nil }
            .compactMap { Self.transactionHashScope(for: $0) }
        guard
            Set(transactionHashes).count == transactionHashes.count,
            unboundHashScopes.allSatisfy({ scope in
                transactionHashScopes.filter { $0 == scope }.count == 1
            })
        else {
            throw NexusToriiError.invalidResponse
        }
        return transactions
    }

    /// Historical rows are immutable recovery evidence. A missing, retired, or
    /// otherwise mismatched chain UUID must be resolved explicitly before any
    /// new Nexus mutation can be admitted; it is never rewritten under the
    /// currently configured endpoint.
    func requireCurrentChainMutationAdmission() throws {
        let transactions = try all()
        guard transactions.allSatisfy(Self.hasCurrentChainIdentity) else {
            throw NexusToriiError.invalidResponse
        }
    }

    @discardableResult
    func put(
        _ transaction: NexusPendingTransaction
    ) throws -> NexusPendingTransaction {
        try validate(transaction, allowsReadOnlyHistoricalChain: false)
        let durableTransaction = try canonicalizedForJournal(transaction)
        try validate(
            durableTransaction,
            allowsReadOnlyHistoricalChain: false
        )
        var transactions = try all()
        if let index = transactions.firstIndex(where: {
            $0.id == durableTransaction.id
        }) {
            let current = transactions[index]
            guard Self.hasSameIdentity(current, durableTransaction) else {
                throw NexusToriiError.invalidResponse
            }
            if
                durableTransaction.updatedAt < current.updatedAt ||
                !Self.canTransition(
                    from: current.state,
                    to: durableTransaction.state
                ) ||
                !Self.preservesDurableProgress(
                    current,
                    durableTransaction
                )
            {
                // An actor can re-enter while status or finality I/O is in
                // flight. Preserve the newer/terminal journal entry instead
                // of letting a stale response regress it.
                return current
            }
            transactions[index] = durableTransaction
        } else {
            // A current transaction must never be appended beside historical
            // evidence. Re-check inside the durable insertion boundary so an
            // earlier UI or coordinator admission cannot become stale.
            guard transactions.allSatisfy(Self.hasCurrentChainIdentity) else {
                throw NexusToriiError.invalidResponse
            }
            if transactions.count == Self.maximumTransactions {
                let oldestTerminalIndex = transactions.indices
                    .filter {
                        let retained = transactions[$0]
                        let retainedConfiguration =
                            NexusNetworkConfiguration.configuration(
                                for: retained.networkId
                            )
                        let isCurrentChain = retainedConfiguration.map {
                            retained.hasCurrentDeploymentIdentity(for: $0)
                        } ?? false
                        // A legacy-unbound or retired-chain row is recovery
                        // evidence, even when its old state was terminal. Do
                        // not silently delete it to admit a current mutation.
                        return isCurrentChain &&
                            retained.state.isTerminal &&
                            !(
                                retained.state == .committed &&
                                    retained.historyReconciledAt == nil
                            )
                    }
                    .min(by: {
                        transactions[$0].updatedAt <
                            transactions[$1].updatedAt
                    })
                guard let oldestTerminalIndex = oldestTerminalIndex else {
                    // Every retained entry may still require reconciliation.
                    // Never prune one merely to admit another mutation.
                    throw NexusToriiError.invalidResponse
                }
                transactions.remove(at: oldestTerminalIndex)
            }
            transactions.append(durableTransaction)
        }
        let transactionHashes = transactions.compactMap {
            Self.transactionHashIdentity(for: $0)
        }
        let transactionHashScopes = transactions.compactMap {
            Self.transactionHashScope(for: $0)
        }
        let unboundHashScopes = transactions
            .filter { $0.chainId == nil }
            .compactMap { Self.transactionHashScope(for: $0) }
        guard
            Set(transactions.map(\.id)).count == transactions.count,
            Set(transactions.map(\.idempotencyKey)).count ==
                transactions.count,
            Set(transactionHashes).count == transactionHashes.count,
            unboundHashScopes.allSatisfy({ scope in
                transactionHashScopes.filter { $0 == scope }.count == 1
            })
        else {
            throw NexusToriiError.invalidResponse
        }
        let data = try encoder.encode(transactions)
        guard data.count <= Self.maximumJournalBytes else {
            throw NexusToriiError.invalidResponse
        }
        try DurableFileWriter.write(
            data,
            to: fileURL,
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )
        return durableTransaction
    }

    private func canonicalizedForJournal(
        _ transaction: NexusPendingTransaction
    ) throws -> NexusPendingTransaction {
        do {
            // Compare and return the exact ISO-8601 representation persisted
            // by this store. Otherwise a subsecond in-memory timestamp can be
            // newer than its own rounded journal value and make an immediate
            // callback appear stale after actor re-entry or app recovery.
            return try decoder.decode(
                NexusPendingTransaction.self,
                from: encoder.encode(transaction)
            )
        } catch {
            throw NexusToriiError.invalidResponse
        }
    }

    private static func hasSameIdentity(
        _ lhs: NexusPendingTransaction,
        _ rhs: NexusPendingTransaction
    ) -> Bool {
        lhs.id == rhs.id &&
            lhs.idempotencyKey == rhs.idempotencyKey &&
            lhs.walletId == rhs.walletId &&
            lhs.networkId == rhs.networkId &&
            lhs.chainId == rhs.chainId &&
            lhs.tairaDeployment == rhs.tairaDeployment &&
            lhs.internalTairaConfigurationSha256 ==
                rhs.internalTairaConfigurationSha256 &&
            lhs.sender == rhs.sender &&
            lhs.receiver == rhs.receiver &&
            lhs.assetDefinitionID == rhs.assetDefinitionID &&
            lhs.amount == rhs.amount &&
            lhs.fee == rhs.fee &&
            Int64(lhs.createdAt.timeIntervalSince1970) ==
                Int64(rhs.createdAt.timeIntervalSince1970) &&
            (
                lhs.hash == nil ||
                    lhs.hash.flatMap(NexusTransactionHash.normalized) ==
                    rhs.hash.flatMap(NexusTransactionHash.normalized)
            )
    }

    private static func transactionHashIdentity(
        for transaction: NexusPendingTransaction
    ) -> String? {
        guard let scope = transactionHashScope(for: transaction) else {
            return nil
        }
        let chainIdentity = transaction.chainId?.uuidString.lowercased() ??
            "legacy-unbound"
        return "\(scope):\(chainIdentity)"
    }

    private static func hasCurrentChainIdentity(
        _ transaction: NexusPendingTransaction
    ) -> Bool {
        NexusNetworkConfiguration.configuration(
            for: transaction.networkId
        ).map {
            transaction.hasCurrentDeploymentIdentity(for: $0)
        } ?? false
    }

    private static func transactionHashScope(
        for transaction: NexusPendingTransaction
    ) -> String? {
        transaction.hash.flatMap(NexusTransactionHash.normalized).map {
            "\(transaction.networkId.rawValue):\($0)"
        }
    }

    private static func canTransition(
        from current: NexusPendingState,
        to next: NexusPendingState
    ) -> Bool {
        switch current {
        case .signing:
            return [.signing, .failedBeforeSubmission, .submitting]
                .contains(next)
        case .failedBeforeSubmission:
            return next == .failedBeforeSubmission
        case .submitting:
            return [
                .submitting,
                .failedBeforeSubmission,
                .submissionUnknown,
                .submitted,
                .approved,
                .committedPendingReconciliation,
                .committed,
                .rejected,
                .expired,
            ].contains(next)
        case .submissionUnknown:
            return [
                .submissionUnknown,
                .submitted,
                .approved,
                .committedPendingReconciliation,
                .committed,
                .rejected,
                .expired,
            ].contains(next)
        case .submitted:
            return [
                .submitted,
                .approved,
                .committedPendingReconciliation,
                .committed,
                .rejected,
                .expired,
            ].contains(next)
        case .approved:
            return [
                .approved,
                .committedPendingReconciliation,
                .committed,
                .rejected,
                .expired,
            ].contains(next)
        case .committedPendingReconciliation:
            return [
                .committedPendingReconciliation,
                .committed,
            ].contains(next)
        case .committed:
            return next == .committed
        case .rejected:
            return next == .rejected
        case .expired:
            return next == .expired
        }
    }

    private static func preservesDurableProgress(
        _ current: NexusPendingTransaction,
        _ candidate: NexusPendingTransaction
    ) -> Bool {
        if current.historyReconciledAt != nil,
           candidate.historyReconciledAt == nil {
            return false
        }
        if current.state == candidate.state,
           let currentBlock = current.terminalBlockHeight,
           candidate.terminalBlockHeight != currentBlock {
            let promotesLegacyZeroHeight =
                current.requiresCommittedHistoryReconciliation &&
                currentBlock == 0 &&
                candidate.state == .committed &&
                candidate.terminalBlockHeight.map({ $0 > 0 }) == true &&
                candidate.historyReconciledAt != nil
            if !promotesLegacyZeroHeight {
                return false
            }
        }
        return true
    }

    private func validate(
        _ transaction: NexusPendingTransaction,
        allowsReadOnlyHistoricalChain: Bool
    ) throws {
        let admittedConfiguration = NexusNetworkConfiguration.configuration(
            for: transaction.networkId
        )
        let configuration: NexusNetworkConfiguration?
        if let admittedConfiguration {
            configuration = admittedConfiguration
        } else if
            allowsReadOnlyHistoricalChain,
            transaction.networkId == .taira,
            let retainedChainId = transaction.chainId
        {
            configuration = NexusNetworkConfiguration.tairaRecovery(
                chainId: retainedChainId
            )
        } else {
            configuration = nil
        }
        guard
            !transaction.walletId.isEmpty,
            transaction.walletId.utf8.count <= 512,
            let configuration,
            let amount = NexusExactDecimal(transaction.amount.rawValue),
            let fee = NexusExactDecimal(transaction.fee.rawValue),
            amount.unscaled > 0,
            fee.unscaled >= 0,
            transaction.createdAt.timeIntervalSince1970.isFinite,
            transaction.updatedAt.timeIntervalSince1970.isFinite,
            transaction.updatedAt >= transaction.createdAt,
            transaction.errorClass.map({
                !$0.isEmpty &&
                    $0.utf8.count <= 256 &&
                    $0.rangeOfCharacter(from: .newlines) == nil
            }) ?? true,
            transaction.assetDefinitionID.map(
                NexusAssetDefinitionIdentity.hasCanonicalWireShape
            ) ?? true,
            transaction.tairaDeployment?.hasCanonicalShape ?? true,
            transaction.internalTairaConfigurationSha256.map({
                $0 != String(repeating: "0", count: 64) &&
                    $0.range(
                        of: "^[0-9a-f]{64}$",
                        options: .regularExpression
                    ) != nil
            }) ?? true,
            transaction.tairaDeployment == nil ||
                transaction.internalTairaConfigurationSha256 == nil,
            transaction.networkId == .taira ||
                (
                    transaction.tairaDeployment == nil &&
                        transaction.internalTairaConfigurationSha256 == nil
                )
        else {
            throw NexusToriiError.invalidResponse
        }
        if !allowsReadOnlyHistoricalChain {
            guard transaction.hasCurrentDeploymentIdentity(
                for: configuration
            ) else {
                throw NexusToriiError.invalidResponse
            }
        }
        try configuration.validate(address: transaction.sender)
        try configuration.validate(address: transaction.receiver)

        if let hash = transaction.hash {
            guard NexusTransactionHash.normalized(hash) != nil else {
                throw NexusToriiError.invalidResponse
            }
        } else {
            switch transaction.state {
            case .signing, .failedBeforeSubmission:
                break
            default:
                throw NexusToriiError.invalidResponse
            }
        }
        if let blockHeight = transaction.terminalBlockHeight {
            guard blockHeight >= 0 else {
                throw NexusToriiError.invalidResponse
            }
        }
        switch transaction.state {
        case .signing, .failedBeforeSubmission:
            guard transaction.terminalBlockHeight == nil else {
                throw NexusToriiError.invalidResponse
            }
        case .committedPendingReconciliation:
            guard
                transaction.terminalBlockHeight.map({ $0 > 0 }) == true,
                transaction.assetDefinitionID != nil,
                transaction.historyReconciledAt == nil
            else {
                throw NexusToriiError.invalidResponse
            }
        case .committed:
            // Nil/zero heights remain readable only for an unreconciled
            // journal written by an older production build. A current
            // reconciliation proof must bind a canonical asset and a strictly
            // positive committed/finalized height before it becomes prunable.
            if transaction.historyReconciledAt != nil {
                guard
                    transaction.terminalBlockHeight.map({ $0 > 0 }) == true,
                    transaction.assetDefinitionID != nil
                else {
                    throw NexusToriiError.invalidResponse
                }
            }
        default:
            break
        }
        if let reconciledAt = transaction.historyReconciledAt {
            guard
                transaction.state == .committed,
                reconciledAt.timeIntervalSince1970.isFinite,
                reconciledAt >= transaction.createdAt,
                reconciledAt <= transaction.updatedAt
            else {
                throw NexusToriiError.invalidResponse
            }
        }
    }
}

actor NexusTransactionCoordinator {
    private let readClient: NexusToriiReading
    private let submissionClient: NexusToriiSubmitting
    private let signer: NexusTransactionSigning
    private let finalityReader: NexusFinalityReading
    private let pendingStore: NexusPendingTransactionStore
    private let settings: SettingsManagerProtocol
    private let featureClient: PIIndexerClient
    private var activeSubmissionIds = Set<UUID>()

    init(
        readClient: NexusToriiReading = NexusToriiReadClient(),
        submissionClient: NexusToriiSubmitting =
            NexusToriiSubmissionClient(),
        signer: NexusTransactionSigning = UnavailableNexusTransactionSigner(),
        finalityReader: NexusFinalityReading = UnavailableNexusFinalityReader(),
        pendingStore: NexusPendingTransactionStore,
        settings: SettingsManagerProtocol = SettingsManager.shared,
        featureClient: PIIndexerClient = PIIndexerClient()
    ) {
        self.readClient = readClient
        self.submissionClient = submissionClient
        self.signer = signer
        self.finalityReader = finalityReader
        self.pendingStore = pendingStore
        self.settings = settings
        self.featureClient = featureClient
    }

    func balance(
        account: NetworkAccount
    ) async throws -> PIQuantity {
        try await currentXorBalance(account: account).quantity
    }

    func currentXorBalance(
        account: NetworkAccount
    ) async throws -> NexusCurrentXorBalance {
        guard
            let configuration = NexusNetworkConfiguration.configuration(
                for: account.networkId
            )
        else {
            throw NexusToriiError.wrongWalletOrNetwork
        }
        let definition = try await readClient.xorAssetDefinition(
            configuration: configuration
        )
        let quantity = try await balance(
            account: account,
            configuration: configuration,
            assetDefinitionID: definition.id
        )
        return NexusCurrentXorBalance(
            quantity: quantity,
            assetDefinitionID: definition.id
        )
    }

    private func balance(
        account: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String,
        requiresCurrentXorIdentity: Bool = true
    ) async throws -> PIQuantity {
        guard NexusAssetDefinitionIdentity.hasCanonicalWireShape(
            assetDefinitionID
        ) else {
            throw NexusToriiError.invalidResponse
        }
        let response = try await readClient.accountAssets(
            account: account.address,
            configuration: configuration,
            asset: assetDefinitionID,
            limit: 100,
            offset: 0
        )
        if requiresCurrentXorIdentity {
            return try NexusBalanceValidator.xorBalance(
                in: response,
                account: account.address,
                configuration: configuration,
                assetDefinitionID: assetDefinitionID
            )
        }
        return try NexusBalanceValidator.exactAssetBalance(
            in: response,
            account: account.address,
            configuration: configuration,
            assetDefinitionID: assetDefinitionID,
            expectedAssetName: nil,
            expectedAssetAlias: nil
        )
    }

    /// Builds the exact confirmation contract without signing. The quote must
    /// come from the reviewed native Iroha/Norito implementation because it
    /// binds the authority, recipient, asset, amount, network and transaction
    /// construction inputs that determine the fee.
    func prepare(
        _ request: NexusTransferRequest,
        selectedAccount: @MainActor @escaping () -> NetworkAccount?
    ) async throws -> NexusPreparedTransfer {
        guard
            let configuration = NexusNetworkConfiguration.configuration(
                for: request.networkId
            ),
            let selected = await selectedAccount(),
            selected.walletId == request.walletId,
            selected.networkId == request.networkId,
            selected.address == request.sender
        else {
            throw NexusToriiError.wrongWalletOrNetwork
        }
        guard signer.isQualified(for: configuration) else {
            throw NexusToriiError.nativeBridgeUnavailable
        }
        guard finalityReader.isQualified(for: configuration) else {
            throw NexusToriiError.finalizedHeadUnavailable
        }
        // An unreadable journal may hide an ambiguous submission, while a
        // readable legacy-unbound or retired-chain row is immutable recovery
        // evidence. Reject both before any PI/Torii request or quote work.
        try await pendingStore.requireCurrentChainMutationAdmission()
        try await validateLiveFeatureFlags(for: request.networkId)
        try configuration.validate(address: request.sender)
        try configuration.validate(address: request.receiver)
        guard
            let amount = NexusExactDecimal(request.amount.rawValue),
            amount.unscaled > 0
        else {
            throw PIIndexerError.invalidQuantity
        }
        let xorDefinition = try await readClient.xorAssetDefinition(
            configuration: configuration
        )
        let quote = try await signer.quoteTransfer(
            request,
            assetDefinitionID: xorDefinition.id,
            configuration: configuration
        )
        try validate(
            quote: quote,
            for: request,
            configuration: configuration,
            assetDefinitionID: xorDefinition.id
        )
        try await validateExpiry(
            quote: quote,
            configuration: configuration
        )
        guard
            let fee = NexusExactDecimal(quote.fee.rawValue),
            fee.unscaled > 0
        else {
            throw PIIndexerError.invalidQuantity
        }
        let available = try await balance(
            account: selected,
            configuration: configuration,
            assetDefinitionID: xorDefinition.id
        )
        guard
            let availableAmount = NexusExactDecimal(available.rawValue),
            availableAmount >= amount + fee
        else {
            throw NexusToriiError.insufficientBalance
        }

        return NexusPreparedTransfer(
            request: request,
            canonicalReceiver: request.receiver,
            assetDefinitionID: xorDefinition.id,
            availableBalance: available,
            quote: quote
        )
    }

    /// Revalidates the displayed quote, selected wallet, feature flags and
    /// balance immediately before signing, then submits the resulting bytes at
    /// most once. A changed quote is intentionally returned as a failure so
    /// the user must review the new fee.
    func send(
        _ prepared: NexusPreparedTransfer,
        selectedAccount: @MainActor @escaping () -> NetworkAccount?
    ) async throws -> NexusPendingTransaction {
        guard prepared.reserveSubmission() else {
            throw NexusToriiError.confirmationAlreadySubmitted
        }
        let request = prepared.request
        guard
            let configuration = NexusNetworkConfiguration.configuration(
                for: request.networkId
            ),
            let selected = await selectedAccount(),
            selected.walletId == request.walletId,
            selected.networkId == request.networkId,
            selected.address == request.sender
        else {
            throw NexusToriiError.wrongWalletOrNetwork
        }
        guard signer.isQualified(for: configuration) else {
            throw NexusToriiError.nativeBridgeUnavailable
        }
        guard finalityReader.isQualified(for: configuration) else {
            throw NexusToriiError.finalizedHeadUnavailable
        }
        try await pendingStore.requireCurrentChainMutationAdmission()
        try await validateLiveFeatureFlags(for: request.networkId)
        try configuration.validate(address: request.sender)
        try configuration.validate(address: prepared.canonicalReceiver)
        guard prepared.canonicalReceiver == request.receiver else {
            throw NexusToriiError.wrongWalletOrNetwork
        }

        let freshDefinition = try await readClient.xorAssetDefinition(
            configuration: configuration
        )
        guard
            freshDefinition.id == prepared.assetDefinitionID,
            freshDefinition.id == prepared.quote.assetDefinitionId
        else {
            throw NexusToriiError.quoteChanged
        }
        let freshQuote = try await signer.quoteTransfer(
            request,
            assetDefinitionID: freshDefinition.id,
            configuration: configuration
        )
        try validate(
            quote: freshQuote,
            for: request,
            configuration: configuration,
            assetDefinitionID: freshDefinition.id
        )
        guard
            freshQuote.quoteIdentity == prepared.quote.quoteIdentity,
            freshQuote.fee == prepared.quote.fee,
            freshQuote.validUntilBlock == prepared.quote.validUntilBlock,
            let amount = NexusExactDecimal(request.amount.rawValue),
            let fee = NexusExactDecimal(freshQuote.fee.rawValue)
        else {
            throw NexusToriiError.quoteChanged
        }
        try await validateExpiry(
            quote: freshQuote,
            configuration: configuration
        )
        let available = try await balance(
            account: selected,
            configuration: configuration,
            assetDefinitionID: freshDefinition.id
        )
        guard
            let availableAmount = NexusExactDecimal(available.rawValue),
            availableAmount >= amount + fee
        else {
            throw NexusToriiError.insufficientBalance
        }

        var pending = NexusPendingTransaction(
            id: UUID(),
            idempotencyKey: UUID(),
            walletId: request.walletId,
            networkId: request.networkId,
            chainId: configuration.chainId,
            tairaDeployment:
                NexusPendingTairaDeploymentIdentity.admitted(
                    for: configuration
                ),
            internalTairaConfigurationSha256:
                NexusPendingTransaction
                    .currentInternalTairaConfigurationSha256(
                        for: configuration
                    ),
            sender: request.sender,
            receiver: request.receiver,
            assetDefinitionID: freshDefinition.id,
            amount: request.amount,
            fee: freshQuote.fee,
            createdAt: Date(),
            updatedAt: Date(),
            hash: nil,
            state: .signing,
            terminalBlockHeight: nil,
            errorClass: nil,
            historyReconciledAt: nil
        )
        activeSubmissionIds.insert(pending.id)
        defer { activeSubmissionIds.remove(pending.id) }

        let signingResult: (
            signed: NexusSignedTransaction,
            pending: NexusPendingTransaction
        )
        do {
            signingResult = try await signAndStage(
                request: request,
                selected: selected,
                configuration: configuration,
                freshQuote: freshQuote,
                amount: amount,
                fee: fee,
                pending: pending,
                selectedAccount: selectedAccount
            )
        } catch {
            do {
                if var persisted = (try await pendingStore.all()).first(
                    where: { $0.id == pending.id }
                ) {
                    persisted.state = .failedBeforeSubmission
                    persisted.updatedAt = Date()
                    persisted.errorClass = String(
                        describing: type(of: error)
                    )
                    _ = try await pendingStore.put(persisted)
                }
            } catch {
                // A journal that became unreadable after signing preparation
                // is itself recovery-required evidence. Never manufacture a
                // replacement row or continue toward transport.
                throw NexusToriiError.invalidResponse
            }
            throw error
        }
        var signed = signingResult.signed
        pending = signingResult.pending
        defer {
            signed.payload.resetBytes(
                in: signed.payload.startIndex ..< signed.payload.endIndex
            )
        }
        guard let expectedHash = NexusTransactionHash.normalized(
            signed.pipelineHash
        ) else {
            // signAndStage validates and journals this immutable hash while
            // holding the lifecycle lease, so reaching this branch indicates
            // in-process memory corruption rather than a retryable failure.
            throw NexusToriiError.invalidResponse
        }

        var acquiredTransportLease: WalletLifecycleLease?
        do {
            guard
                let lifecycleLease =
                    try WalletLifecycleCoordinator.shared
                        .tryAcquireForMutableWalletAccess()
            else {
                throw WalletNetworkMigrationError
                    .lifecycleMutationBusy
            }
            acquiredTransportLease = lifecycleLease
            try Task.checkCancellation()
            try await pendingStore.requireCurrentChainMutationAdmission()
            try await validateLiveFeatureFlags(for: request.networkId)
            try await validateExpiry(
                quote: freshQuote,
                configuration: configuration
            )
            let transportDefinition = try await readClient.xorAssetDefinition(
                configuration: configuration
            )
            guard
                transportDefinition.id == pending.assetDefinitionID
            else {
                throw NexusToriiError.quoteChanged
            }
            guard
                let immediatelySelected = await selectedAccount(),
                immediatelySelected == selected,
                sendAvailabilityAllows(request.networkId),
                signer.isQualified(for: configuration),
                finalityReader.isQualified(for: configuration)
            else {
                throw NexusToriiError.wrongWalletOrNetwork
            }
            try verifyActiveWalletIdentity(
                request: request,
                selected: selected
            )
            try await pendingStore.requireCurrentChainMutationAdmission()
        } catch {
            acquiredTransportLease?.release()
            // Exact bytes and their hash were staged, but Torii was never
            // called. This is definitive, not an ambiguous submission.
            pending.state = .failedBeforeSubmission
            pending.updatedAt = Date()
            pending.errorClass = String(
                describing: type(of: error)
            )
            pending = try await pendingStore.put(pending)
            throw error
        }
        guard let transportLease = acquiredTransportLease else {
            throw WalletNetworkMigrationError.lifecycleMutationBusy
        }
        defer { transportLease.release() }

        do {
            try WalletRecoveryCapabilityGate.shared
                .requireAuthorizedLifecycleContinuation()
        } catch {
            pending.state = .failedBeforeSubmission
            pending.updatedAt = Date()
            pending.errorClass = String(
                describing: type(of: error)
            )
            pending = try await pendingStore.put(pending)
            throw error
        }

        let immutableSignedPayload = signed.payload
        let immutableIdempotencyKey = pending.idempotencyKey
        do {
            async let submittedReceipt = submissionClient.submit(
                signedNorito: immutableSignedPayload,
                idempotencyKey: immutableIdempotencyKey,
                configuration: configuration
            )
            // The transport task now owns the immutable signed request. Do
            // not stall account switching/deletion while Torii responds.
            transportLease.release()
            let receipt = try await submittedReceipt
            try receipt.validate(expectedHash: expectedHash)
            pending.state = .submitted
            pending.updatedAt = Date()
            pending = try await pendingStore.put(pending)
        } catch {
            // A timeout/disconnect after bytes left the device is ambiguous.
            // Persist it and require status reconciliation; never auto-submit.
            pending.state = .submissionUnknown
            pending.updatedAt = Date()
            pending.errorClass = String(describing: type(of: error))
            pending = try await pendingStore.put(pending)
            if pending.state.isTerminal {
                return pending
            }
            throw NexusToriiError.ambiguousSubmission
        }

        return await reconcileUntilTerminal(pending)
    }

    /// Holds the same process-wide lifecycle lease as account import,
    /// switching, and explicit removal from the last authoritative checks
    /// through signing and durable hash journaling. Transport then reacquires
    /// a fresh recovery-gated lease and revalidates identity before Torii.
    private func signAndStage(
        request: NexusTransferRequest,
        selected: NetworkAccount,
        configuration: NexusNetworkConfiguration,
        freshQuote: NexusTransferFeeQuote,
        amount: NexusExactDecimal,
        fee: NexusExactDecimal,
        pending originalPending: NexusPendingTransaction,
        selectedAccount: @MainActor @escaping () -> NetworkAccount?
    ) async throws -> (
        signed: NexusSignedTransaction,
        pending: NexusPendingTransaction
    ) {
        let lifecycleLease =
            try await WalletLifecycleCoordinator.shared
                .acquireForMutableWalletAccessAsync()
        defer { lifecycleLease.release() }
        try Task.checkCancellation()
        try await pendingStore.requireCurrentChainMutationAdmission()

        let finalDefinition = try await readClient.xorAssetDefinition(
            configuration: configuration
        )
        guard
            finalDefinition.id == freshQuote.assetDefinitionId,
            originalPending.assetDefinitionID == finalDefinition.id
        else {
            throw NexusToriiError.quoteChanged
        }
        let finalQuote = try await signer.quoteTransfer(
            request,
            assetDefinitionID: finalDefinition.id,
            configuration: configuration
        )
        try validate(
            quote: finalQuote,
            for: request,
            configuration: configuration,
            assetDefinitionID: finalDefinition.id
        )
        guard
            finalQuote.quoteIdentity == freshQuote.quoteIdentity,
            finalQuote.fee == freshQuote.fee,
            finalQuote.validUntilBlock == freshQuote.validUntilBlock
        else {
            throw NexusToriiError.quoteChanged
        }
        try await validateExpiry(
            quote: finalQuote,
            configuration: configuration
        )
        let finalAvailable = try await balance(
            account: selected,
            configuration: configuration,
            assetDefinitionID: finalDefinition.id
        )
        guard
            let finalAvailableAmount = NexusExactDecimal(
                finalAvailable.rawValue
            ),
            finalAvailableAmount >= amount + fee
        else {
            throw NexusToriiError.insufficientBalance
        }
        try await validateLiveFeatureFlags(for: request.networkId)
        guard
            let immediatelySelected = await selectedAccount(),
            immediatelySelected == selected,
            sendAvailabilityAllows(request.networkId),
            signer.isQualified(for: configuration),
            finalityReader.isQualified(for: configuration)
        else {
            throw NexusToriiError.wrongWalletOrNetwork
        }
        try verifyActiveWalletIdentity(
            request: request,
            selected: selected
        )

        // Publish the pre-sign marker while the same lifecycle lease excludes
        // account switching and explicit deletion. If deletion acquired the
        // lease first, the identity check above fails and no orphan row is
        // created for a wallet that has already been removed.
        var pending = try await pendingStore.put(originalPending)
        // The durable pre-sign write above is an actor-reentrancy point. Pair
        // the live PI refresh with one last synchronous snapshot check at the
        // actual signer boundary so a concurrent emergency refresh cannot
        // leave stale authority in use.
        let signingDefinition = try await readClient.xorAssetDefinition(
            configuration: configuration
        )
        guard signingDefinition.id == finalDefinition.id else {
            throw NexusToriiError.quoteChanged
        }
        guard
            let signingAccount = await selectedAccount(),
            signingAccount == selected
        else {
            throw NexusToriiError.wrongWalletOrNetwork
        }
        guard sendAvailabilityAllows(request.networkId) else {
            throw NexusToriiError.sendsDisabled
        }
        guard signer.isQualified(for: configuration) else {
            throw NexusToriiError.nativeBridgeUnavailable
        }
        guard finalityReader.isQualified(for: configuration) else {
            throw NexusToriiError.finalizedHeadUnavailable
        }
        try verifyActiveWalletIdentity(
            request: request,
            selected: selected
        )
        try await pendingStore.requireCurrentChainMutationAdmission()
        var signed = try await signer.signTransfer(
            request,
            assetDefinitionID: finalDefinition.id,
            quote: finalQuote,
            configuration: configuration
        )
        do {
            try await pendingStore.requireCurrentChainMutationAdmission()
            try await validateLiveFeatureFlags(for: request.networkId)
            let postSignDefinition = try await readClient.xorAssetDefinition(
                configuration: configuration
            )
            guard postSignDefinition.id == finalDefinition.id else {
                throw NexusToriiError.quoteChanged
            }
            guard
                let revalidated = await selectedAccount(),
                revalidated == selected,
                sendAvailabilityAllows(request.networkId),
                signer.isQualified(for: configuration),
                finalityReader.isQualified(for: configuration)
            else {
                throw NexusToriiError.wrongWalletOrNetwork
            }
            try verifyActiveWalletIdentity(
                request: request,
                selected: selected
            )
            try await pendingStore.requireCurrentChainMutationAdmission()
            guard let expectedHash = NexusTransactionHash.normalized(
                signed.pipelineHash
            ) else {
                throw NexusToriiError.invalidResponse
            }
            pending.state = .submitting
            pending.hash = expectedHash
            pending.updatedAt = Date()
            pending = try await pendingStore.put(pending)
            return (signed, pending)
        } catch {
            signed.payload.resetBytes(
                in: signed.payload.startIndex ..< signed.payload.endIndex
            )
            throw error
        }
    }

    private func verifyActiveWalletIdentity(
        request: NexusTransferRequest,
        selected: NetworkAccount
    ) throws {
        guard
            let snapshot = try WalletNetworkStore().load(),
            snapshot.selectedWalletId == request.walletId,
            snapshot.wallets.contains(where: {
                $0.id == request.walletId &&
                    $0.secretSource == .mnemonicEntropy
            }),
            snapshot.accounts.first(where: {
                $0.walletId == request.walletId &&
                    $0.networkId == request.networkId
            }) == selected
        else {
            throw NexusToriiError.wrongWalletOrNetwork
        }
    }

    private func validate(
        quote: NexusTransferFeeQuote,
        for request: NexusTransferRequest,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) throws {
        guard
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                assetDefinitionID
            ),
            quote.networkId == configuration.networkId,
            quote.authority == request.sender,
            quote.receiver == request.receiver,
            quote.assetDefinitionId == assetDefinitionID,
            quote.amount == request.amount,
            !quote.quoteIdentity.isEmpty,
            quote.validUntilBlock.map({ $0 > 0 }) ?? true,
            let fee = NexusExactDecimal(quote.fee.rawValue),
            fee.unscaled > 0
        else {
            throw NexusToriiError.invalidResponse
        }
    }

    private func validateExpiry(
        quote: NexusTransferFeeQuote,
        configuration: NexusNetworkConfiguration
    ) async throws {
        guard let validUntilBlock = quote.validUntilBlock else {
            return
        }
        guard finalityReader.isQualified(for: configuration) else {
            throw NexusToriiError.finalizedHeadUnavailable
        }
        let checkpoint = try await finalityReader.finalizedCheckpoint(
            for: configuration
        )
        let finalizedBlock = try checkpoint.requireHeight(
            for: configuration
        )
        guard finalizedBlock <= validUntilBlock else {
            throw NexusToriiError.quoteExpired
        }
    }

    private func sendAvailabilityAllows(_ networkId: NetworkId) -> Bool {
        NexusSendAvailabilityPolicy.permits(
            networkId: networkId,
            nexusEnabled: settings.nexusEnabled,
            sendsEnabled: settings.nexusSendsEnabled,
            tairaEnabled: settings.isTairaEnabled
        )
    }

    private func validateLiveFeatureFlags(
        for networkId: NetworkId
    ) async throws {
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
            throw NexusToriiError.sendsDisabled
        }
        guard
            config.nexusAvailable,
            config.nexusSendsAvailable,
            sendAvailabilityAllows(networkId)
        else {
            throw NexusToriiError.sendsDisabled
        }
    }

    func resumePending() async throws -> [NexusPendingTransaction] {
        try Task.checkCancellation()
        let transactions = try await pendingStore.all()
        var updated: [NexusPendingTransaction] = []
        for var transaction in transactions {
            try Task.checkCancellation()
            // Actor methods are re-entrant across signer and transport awaits.
            // A record owned by this live process is not an interrupted
            // restart record and must be advanced only by its send task.
            let ownedByLiveSubmission = activeSubmissionIds.contains(
                transaction.id
            )
            if ownedByLiveSubmission {
                updated.append(transaction)
                continue
            }
            guard
                let journalConfiguration =
                    NexusNetworkConfiguration.configuration(
                        for: transaction.networkId
                    ),
                transaction.hasCurrentDeploymentIdentity(
                    for: journalConfiguration
                )
            else {
                // Retain pre-chain-binding or retired-chain evidence exactly
                // as written. Never reinterpret it under today's endpoint,
                // sign a replacement, or mark it terminal automatically.
                updated.append(transaction)
                continue
            }
            if NexusPendingRecoveryPolicy
                .shouldFailAsInterruptedPreSubmission(
                    state: transaction.state,
                    hash: transaction.hash,
                    ownedByLiveSubmission: ownedByLiveSubmission
                ) {
                // No hash means bytes were never durably staged for transport.
                // It is safe to close this interrupted pre-submission record,
                // and unsafe to synthesize/sign a replacement on restart.
                transaction.state = .failedBeforeSubmission
                transaction.updatedAt = Date()
                transaction.errorClass = "interrupted_before_submission"
                updated.append(try await pendingStore.put(transaction))
                continue
            }
            let needsLegacyCommittedReconciliation =
                transaction.requiresCommittedHistoryReconciliation
            if
                (transaction.state.isTerminal &&
                    !needsLegacyCommittedReconciliation) ||
                transaction.hash == nil
            {
                updated.append(transaction)
                continue
            }
            do {
                updated.append(try await reconcile(transaction))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                updated.append(transaction)
            }
        }
        try Task.checkCancellation()
        return updated
    }

    private func reconcile(
        _ transaction: NexusPendingTransaction
    ) async throws -> NexusPendingTransaction {
        guard
            let hash = transaction.hash,
            let assetDefinitionID = transaction.assetDefinitionID,
            NexusAssetDefinitionIdentity.hasCanonicalWireShape(
                assetDefinitionID
            ),
            let configuration = NexusNetworkConfiguration.configuration(
                for: transaction.networkId
            ),
            transaction.hasCurrentDeploymentIdentity(
                for: configuration
            )
        else {
            return transaction
        }
        var transaction = transaction
        let status = try await readClient.status(
            hash: hash,
            configuration: configuration
        )
        guard
            let expectedHash = NexusTransactionHash.normalized(hash),
            NexusTransactionHash.normalized(status.hash) == expectedHash
        else {
            throw NexusToriiError.transactionHashMismatch
        }
        guard status.hasAuthoritativeGlobalResolution else {
            throw NexusToriiError.invalidResponse
        }

        switch status.status.kind.lowercased() {
        case "committed", "applied":
            // Pipeline status alone is not enough to call a send final. New
            // records first persist a nonterminal state, then require balance
            // read-back and an exact committed history match. Legacy records
            // already marked committed retain that monotonic transport state
            // and gain only the reconciliation proof on success. Any
            // interruption leaves either form recoverable without resubmission.
            let wasLegacyUnreconciledCommit =
                transaction.requiresCommittedHistoryReconciliation
            guard
                let committedBlockHeight = status.status.blockHeight,
                committedBlockHeight > 0
            else {
                return transaction
            }
            transaction.terminalBlockHeight = committedBlockHeight
            transaction.updatedAt = Date()
            transaction.errorClass = nil
            if !wasLegacyUnreconciledCommit {
                transaction.state = .committedPendingReconciliation
                transaction = try await pendingStore.put(transaction)
                if transaction.state.isTerminal {
                    return transaction
                }
            }
            let lifecycleLease = await WalletLifecycleCoordinator.shared
                .acquireAsync()
            defer { lifecycleLease.release() }
            do {
                try WalletRecoveryCapabilityGate.shared
                    .requireAuthorizedLifecycleContinuation()
            } catch {
                return transaction
            }
            guard
                let store = try? WalletNetworkStore(),
                let snapshot = try? store.load(),
                let account = snapshot.accounts.first(where: {
                    $0.walletId == transaction.walletId &&
                        $0.networkId == transaction.networkId &&
                        $0.address == transaction.sender
                }),
                let expectedAmount = NexusExactDecimal(
                    transaction.amount.rawValue
                )
            else {
                return transaction
            }
            do {
                guard finalityReader.isQualified(for: configuration) else {
                    return transaction
                }
                let finalizedCheckpoint = try await finalityReader
                    .finalizedCheckpoint(for: configuration)
                let finalizedBlockHeight = try finalizedCheckpoint
                    .requireHeight(for: configuration)
                guard finalizedBlockHeight >= committedBlockHeight else {
                    return transaction
                }
                guard try await readClient
                    .hasAuthoritativeCommittedTransaction(
                        account: account.address,
                        configuration: configuration,
                        assetDefinitionID: assetDefinitionID,
                        transactionHash: expectedHash
                    ) else {
                    return transaction
                }
                _ = try await balance(
                    account: account,
                    configuration: configuration,
                    assetDefinitionID: assetDefinitionID,
                    requiresCurrentXorIdentity: false
                )
                let history = try await readClient.committedXorTransfers(
                    account: account.address,
                    configuration: configuration,
                    assetDefinitionID: assetDefinitionID
                )
                guard NexusCommittedHistoryReconciliation.matchesExactlyOne(
                    history: history,
                    transactionHash: expectedHash,
                    sender: account.address,
                    receiver: transaction.receiver,
                    amount: expectedAmount
                ) else {
                    return transaction
                }
                transaction.state = .committed
                transaction.historyReconciledAt = Date()
            } catch {
                return transaction
            }
        case "rejected":
            transaction.state = .rejected
        case "expired":
            transaction.state = .expired
        case "approved":
            transaction.state = .approved
        default:
            transaction.state = .submitted
        }
        transaction.terminalBlockHeight = status.status.blockHeight
        transaction.updatedAt = Date()
        transaction.errorClass = nil
        return try await pendingStore.put(transaction)
    }

    private func reconcileUntilTerminal(
        _ transaction: NexusPendingTransaction
    ) async -> NexusPendingTransaction {
        var current = transaction
        let delays: [UInt64] = [250, 500, 1_000, 2_000, 4_000]
        for delay in delays {
            do {
                current = try await reconcile(current)
                if current.state.isTerminal {
                    return current
                }
            } catch NexusToriiError.httpStatus(404) {
                // A Torii restart may temporarily lose its status cache.
                // Keep polling; never interpret this as permission to submit.
            } catch {
                return current
            }
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
        }
        return current
    }
}

/// One process-wide owner for the Nexus pending journal and reconciliation
/// actor. Startup/foreground recovery and UI refreshes must share these exact
/// instances so concurrent file-backed actors cannot race or strand a hidden
/// testnet transaction. Recovery is status-only and never signs or resubmits.
@MainActor
final class NexusTransactionRuntime {
    static let shared = NexusTransactionRuntime()

    let pendingStore: NexusPendingTransactionStore?
    let coordinator: NexusTransactionCoordinator?
    let initializationFailed: Bool
    /// Remains false until both the reviewed native transaction signer and
    /// challenge-bound finalized-head verifier are installed for this build.
    /// A pending-journal coordinator alone is not mutation capability.
    let mutationAdapterAvailable: Bool

    private var recoveryTask: Task<Void, Never>?
    private var walletStorageReady = false
    private var restartAfterStorageReady = false

    private init() {
        mutationAdapterAvailable = false
        do {
            let store = try NexusPendingTransactionStore()
            pendingStore = store
            coordinator = NexusTransactionCoordinator(pendingStore: store)
            initializationFailed = false
        } catch {
            pendingStore = nil
            coordinator = nil
            initializationFailed = true
        }
    }

    func prepareForWalletStorageMigration() {
        walletStorageReady = false
        restartAfterStorageReady = false
        recoveryTask?.cancel()
    }

    func markWalletStorageReadyAndResume() {
        walletStorageReady = true
        if recoveryTask != nil {
            restartAfterStorageReady = true
            return
        }
        resumePendingAfterProcessStart()
    }

    func resumePendingAfterProcessStart() {
        guard
            walletStorageReady,
            recoveryTask == nil,
            let coordinator
        else {
            return
        }
        recoveryTask = Task { [weak self] in
            // Errors remain represented by the protected journal/UI state;
            // never log transaction contents, hashes, or account identifiers.
            _ = try? await coordinator.resumePending()
            let shouldRestart = self?.restartAfterStorageReady == true &&
                self?.walletStorageReady == true
            self?.recoveryTask = nil
            self?.restartAfterStorageReady = false
            if shouldRestart {
                self?.resumePendingAfterProcessStart()
            }
        }
    }
}
