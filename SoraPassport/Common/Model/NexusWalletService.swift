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
    /// The generic Norito quantity parser retains its unsigned-byte ceiling for
    /// Minamoto compatibility. Taira's native XOR contract is fixed at scale 9.
    static let maximumScale = 255
    static let tairaMaximumScale = 9

    static func maximumScale(for networkId: NetworkId) -> Int {
        networkId == .taira ? tairaMaximumScale : maximumScale
    }

    static func accepts(
        _ quantity: PIQuantity,
        networkId: NetworkId? = nil,
        allowingZero: Bool = false
    ) -> Bool {
        guard let value = NexusExactDecimal(quantity.rawValue) else {
            return false
        }
        let scaleLimit = networkId.map { maximumScale(for: $0) } ?? maximumScale
        guard value.scale <= scaleLimit else {
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
        tairaEnabled: Bool,
        networkAdmitted: Bool,
        signerQualified: Bool,
        finalityQualified: Bool
    ) -> Bool {
        nexusEnabled &&
            sendsEnabled &&
            networkAdmitted &&
            signerQualified &&
            finalityQualified &&
            (networkId != .taira || tairaEnabled)
    }
}

enum NexusToriiError: LocalizedError {
    case invalidRoute
    case invalidResponse
    case mcpContractMismatch
    case mcpNotEnabled
    case deploymentUnavailable
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
        case .mcpContractMismatch:
            return "Torii does not expose the reviewed wallet MCP contract."
        case .mcpNotEnabled:
            return "The public Taira endpoint does not have Torii MCP enabled."
        case .deploymentUnavailable:
            return "The public Torii endpoint cannot reach an authoritative network route."
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

/// Bounded RFC JSON admission performed before Foundation can normalize number
/// tokens or collapse duplicate object names. Nexus wire contracts use numeric
/// JSON tokens only for exact 64-bit integer control fields; quantities remain
/// strings.
enum NexusStrictJSONAdmission {
    private static let maximumBytes = 2 * 1_024 * 1_024
    private static let maximumDepth = 64
    private static let maximumTokens = 500_000

    static func validate(_ data: Data) throws {
        guard
            !data.isEmpty,
            data.count <= maximumBytes,
            String(data: data, encoding: .utf8) != nil
        else {
            throw NexusToriiError.invalidResponse
        }
        var parser = Parser(
            bytes: Array(data),
            maximumDepth: maximumDepth,
            maximumTokens: maximumTokens
        )
        try parser.parseDocument()
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        using decoder: JSONDecoder
    ) throws -> Value {
        try validate(data)
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NexusToriiError.invalidResponse
        }
    }

    private struct Parser {
        let bytes: [UInt8]
        let maximumDepth: Int
        let maximumTokens: Int
        var index = 0
        var tokenCount = 0

        mutating func parseDocument() throws {
            skipWhitespace()
            try parseValue(depth: 1)
            skipWhitespace()
            guard index == bytes.count else { try invalid() }
        }

        private mutating func parseValue(depth: Int) throws {
            guard depth <= maximumDepth else { try invalid() }
            try admitToken()
            guard let byte = current else { try invalid() }
            switch byte {
            case 0x7B:
                try parseObject(depth: depth)
            case 0x5B:
                try parseArray(depth: depth)
            case 0x22:
                _ = try parseString()
            case 0x74:
                try consumeLiteral([0x74, 0x72, 0x75, 0x65])
            case 0x66:
                try consumeLiteral([0x66, 0x61, 0x6C, 0x73, 0x65])
            case 0x6E:
                try consumeLiteral([0x6E, 0x75, 0x6C, 0x6C])
            case 0x2D, 0x30 ... 0x39:
                try parseInteger()
            default:
                try invalid()
            }
        }

        private mutating func parseObject(depth: Int) throws {
            try consume(0x7B)
            skipWhitespace()
            if consumeIfPresent(0x7D) { return }
            var names = Set<String>()
            while true {
                try admitToken()
                let name = try parseString()
                guard names.insert(name).inserted else { try invalid() }
                skipWhitespace()
                try consume(0x3A)
                skipWhitespace()
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consumeIfPresent(0x7D) { return }
                try consume(0x2C)
                skipWhitespace()
            }
        }

        private mutating func parseArray(depth: Int) throws {
            try consume(0x5B)
            skipWhitespace()
            if consumeIfPresent(0x5D) { return }
            while true {
                try parseValue(depth: depth + 1)
                skipWhitespace()
                if consumeIfPresent(0x5D) { return }
                try consume(0x2C)
                skipWhitespace()
            }
        }

        private mutating func parseString() throws -> String {
            try consume(0x22)
            var value = ""
            var segmentStart = index
            while let byte = current {
                if byte == 0x22 {
                    try appendUTF8Segment(segmentStart ..< index, to: &value)
                    index += 1
                    return value
                }
                if byte == 0x5C {
                    try appendUTF8Segment(segmentStart ..< index, to: &value)
                    index += 1
                    guard let escape = current else { try invalid() }
                    index += 1
                    switch escape {
                    case 0x22: value.append("\"")
                    case 0x5C: value.append("\\")
                    case 0x2F: value.append("/")
                    case 0x62: value.append("\u{08}")
                    case 0x66: value.append("\u{0C}")
                    case 0x6E: value.append("\n")
                    case 0x72: value.append("\r")
                    case 0x74: value.append("\t")
                    case 0x75:
                        let first = try parseHexCodeUnit()
                        let scalar: UInt32
                        if (0xD800 ... 0xDBFF).contains(first) {
                            guard
                                consumeIfPresent(0x5C),
                                consumeIfPresent(0x75)
                            else {
                                try invalid()
                            }
                            let second = try parseHexCodeUnit()
                            guard (0xDC00 ... 0xDFFF).contains(second) else {
                                try invalid()
                            }
                            scalar = 0x1_0000 +
                                (UInt32(first - 0xD800) << 10) +
                                UInt32(second - 0xDC00)
                        } else {
                            guard !(0xDC00 ... 0xDFFF).contains(first) else {
                                try invalid()
                            }
                            scalar = UInt32(first)
                        }
                        guard let unicode = UnicodeScalar(scalar) else {
                            try invalid()
                        }
                        value.unicodeScalars.append(unicode)
                    default:
                        try invalid()
                    }
                    segmentStart = index
                    continue
                }
                guard byte >= 0x20 else { try invalid() }
                index += 1
            }
            try invalid()
        }

        private mutating func parseHexCodeUnit() throws -> UInt16 {
            guard index + 4 <= bytes.count else { try invalid() }
            var value: UInt16 = 0
            for _ in 0 ..< 4 {
                let digit = bytes[index]
                index += 1
                let nibble: UInt16
                switch digit {
                case 0x30 ... 0x39: nibble = UInt16(digit - 0x30)
                case 0x41 ... 0x46: nibble = UInt16(digit - 0x41 + 10)
                case 0x61 ... 0x66: nibble = UInt16(digit - 0x61 + 10)
                default: try invalid()
                }
                value = (value << 4) | nibble
            }
            return value
        }

        private mutating func parseInteger() throws {
            let start = index
            let negative = consumeIfPresent(0x2D)
            guard let first = current else { try invalid() }
            if first == 0x30 {
                index += 1
                guard current.map({ !(0x30 ... 0x39).contains($0) }) ?? true
                else {
                    try invalid()
                }
            } else if (0x31 ... 0x39).contains(first) {
                repeat { index += 1 } while current.map {
                    (0x30 ... 0x39).contains($0)
                } ?? false
            } else {
                try invalid()
            }
            guard let token = String(
                bytes: bytes[start ..< index],
                encoding: .utf8
            ) else {
                try invalid()
            }
            if negative {
                guard let value = Int64(token), String(value) == token else {
                    try invalid()
                }
            } else {
                guard let value = UInt64(token), String(value) == token else {
                    try invalid()
                }
            }
        }

        private mutating func consumeLiteral(_ literal: [UInt8]) throws {
            guard
                index + literal.count <= bytes.count,
                Array(bytes[index ..< index + literal.count]) == literal
            else {
                try invalid()
            }
            index += literal.count
        }

        private mutating func appendUTF8Segment(
            _ range: Range<Int>,
            to value: inout String
        ) throws {
            guard let segment = String(
                bytes: bytes[range],
                encoding: .utf8
            ) else {
                try invalid()
            }
            value.append(segment)
        }

        private mutating func admitToken() throws {
            tokenCount += 1
            guard tokenCount <= maximumTokens else { try invalid() }
        }

        private mutating func skipWhitespace() {
            while let byte = current,
                  byte == 0x20 || byte == 0x09 ||
                  byte == 0x0A || byte == 0x0D {
                index += 1
            }
        }

        private mutating func consume(_ expected: UInt8) throws {
            guard consumeIfPresent(expected) else { try invalid() }
        }

        private mutating func consumeIfPresent(_ expected: UInt8) -> Bool {
            guard current == expected else { return false }
            index += 1
            return true
        }

        private var current: UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        private func invalid() throws -> Never {
            throw NexusToriiError.invalidResponse
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

    var exactWireStringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
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
    let name: String?
    let alias: String?
    let aliasBinding: AliasBinding?
    let ownedBy: String?
    let metadata: NexusJSONValue?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case alias
        case aliasBinding = "alias_binding"
        case ownedBy = "owned_by"
        case metadata
    }

    init(
        id: String,
        name: String? = nil,
        alias: String? = nil,
        aliasBinding: AliasBinding? = nil,
        ownedBy: String? = nil,
        metadata: NexusJSONValue? = nil
    ) {
        self.id = id
        self.name = name
        self.alias = alias
        self.aliasBinding = aliasBinding
        self.ownedBy = ownedBy
        self.metadata = metadata
    }
}

enum NexusAssetDefinitionIdentity {
    static let xorAlias = "xor#universal"
    static let xorName = "xor"
    static let tairaXorDefinitionID = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"

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

    static func isQualifiedXorDefinitionID(
        _ value: String,
        configuration: NexusNetworkConfiguration
    ) -> Bool {
        guard hasCanonicalWireShape(value) else {
            return false
        }
        return configuration.networkId != .taira ||
            value == tairaXorDefinitionID
    }

    static func validateXor(
        _ definition: NexusAssetDefinition,
        configuration: NexusNetworkConfiguration? = nil
    ) throws {
        guard hasCanonicalWireShape(definition.id) else {
            throw NexusToriiError.invalidResponse
        }
        let bindingIsValid = definition.aliasBinding.map {
            $0.alias == xorAlias &&
                ["permanent", "leased_active"].contains($0.status)
        }
        if let configuration, configuration.networkId == .taira {
            // The current explorer projection intentionally omits mutable alias
            // metadata. Taira's first release binds the immutable native ID;
            // optional descriptive witnesses are still checked when present.
            guard
                definition.id == tairaXorDefinitionID,
                definition.name.map({ $0 == xorName }) ?? true,
                definition.alias.map({ $0 == xorAlias }) ?? true,
                bindingIsValid ?? true
            else {
                throw NexusToriiError.invalidResponse
            }
            return
        }
        guard
            configuration.map({
                isQualifiedXorDefinitionID(
                    definition.id,
                    configuration: $0
                )
            }) ?? true,
            definition.name == xorName,
            definition.alias == xorAlias,
            bindingIsValid == true
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

    init(
        items: [Item],
        hasMore: Bool,
        countMode: String,
        total: Int64
    ) {
        self.items = items
        self.hasMore = hasMore
        self.countMode = countMode
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([Item].self, forKey: .items)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
        countMode = try container.decode(String.self, forKey: .countMode)
        total = try container.decode(Int64.self, forKey: .total)
    }
}

/// Current `/v1/accounts/{account}/assets` body exposed by curated Torii MCP.
private struct NexusTairaAccountAssetPage: Decodable {
    let items: [NexusAccountAssetList.Item]
    let total: Int64
}

enum NexusBalanceValidator {
    static func xorBalance(
        in response: NexusAccountAssetList,
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) throws -> PIQuantity {
        guard NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
            assetDefinitionID,
            configuration: configuration
        ) else {
            throw NexusToriiError.invalidResponse
        }
        return try exactAssetBalance(
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
        guard NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
            assetDefinitionID,
            configuration: configuration
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
                    networkId: configuration.networkId,
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
    private var matchedExpectedHash = false

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
            matchedExpectedHash = true
        }

        nextOffset += page.items.count
        if UInt64(nextOffset) == page.total {
            return matchedExpectedHash ? .found : .absent
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

struct NexusMCPRequest: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: NexusJSONValue

    init(
        id: String,
        method: String = "tools/call",
        params: NexusJSONValue
    ) {
        self.id = id
        self.method = method
        self.params = params
    }
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

/// Recognizes only the bounded canonical deployment-health markers emitted by
/// Torii. Descriptive substrings are deliberately not authoritative: a body
/// such as "not route_unavailable" must remain a generic server failure.
enum NexusToriiDeploymentHealthContract {
    private static let knownMarkers: Set<String> = [
        "route_unavailable", "permission_denied", "not_found", "error",
    ]

    static func isRouteUnavailable(
        rejectCode: String?,
        body: NexusJSONValue?
    ) throws -> Bool {
        var markers: [String] = []
        if let rejectCode, knownMarkers.contains(rejectCode) {
            markers.append(rejectCode)
        }
        if let object = body?.objectValue,
           [
               Set(["code", "message"]),
               Set(["code", "details", "message"]),
           ].contains(Set(object.keys)),
           let code = boundedExactString(object["code"], maximumBytes: 128),
           let message = boundedExactString(
               object["message"],
               maximumBytes: 4_096
           )
        {
            if knownMarkers.contains(code) {
                markers.append(code)
            }
            if knownMarkers.contains(message) {
                markers.append(message)
            }
        }
        let distinct = Set(markers)
        guard distinct.count <= 1 else {
            throw NexusToriiError.invalidResponse
        }
        return distinct == ["route_unavailable"]
    }

    static func isRouteUnavailable(
        rejectCode: String?,
        data: Data,
        decoder: JSONDecoder
    ) throws -> Bool {
        let body = try? NexusStrictJSONAdmission.decode(
            NexusJSONValue.self,
            from: data,
            using: decoder
        )
        if try isRouteUnavailable(rejectCode: rejectCode, body: body) {
            return true
        }
        return rejectCode == nil && data == Data("route_unavailable".utf8)
    }

    private static func boundedExactString(
        _ value: NexusJSONValue?,
        maximumBytes: Int
    ) -> String? {
        guard
            let text = value?.exactWireStringValue,
            !text.isEmpty,
            text == text.trimmingCharacters(in: .whitespacesAndNewlines),
            text.utf8.count <= maximumBytes
        else {
            return nil
        }
        return text
    }
}

/// Current curated Torii MCP contract used exclusively by public Taira.
/// Discovery is additive: unrelated tools and future optional schema fields do
/// not invalidate the wallet, while every field the wallet sends remains typed
/// and pinned to the advertised tool-set version.
enum NexusTairaMCPToolContract {
    static let protocolVersion = "2025-06-18"
    static let serverName = "iroha-torii-mcp"

    enum Tool: String, CaseIterable, Hashable {
        case health = "iroha.health"
        case accountAssets = "iroha.accounts.assets"
        case assetDefinition = "iroha.assets.definitions.get"
        case transactionStatus = "iroha.transactions.status"
        case instructions = "iroha.instructions.list"
        case submitAndWait = "iroha.transactions.submit_and_wait"

        fileprivate var requestProperties: [String: SchemaType] {
            switch self {
            case .health:
                return [:]
            case .accountAssets:
                return [
                    "account_id": .scalar("string"),
                    "asset": .scalar("string"),
                    "limit": .scalar("integer"),
                    "offset": .scalar("integer"),
                    "scope": .scalar("string"),
                    "accept": .scalar("string"),
                ]
            case .assetDefinition:
                return [
                    "definition_id": .scalar("string"),
                    "accept": .scalar("string"),
                ]
            case .transactionStatus:
                return [
                    "hash": .scalar("string"),
                    "scope": .scalar("string"),
                    "accept": .scalar("string"),
                ]
            case .instructions:
                return [
                    "account": .scalar("string"),
                    "asset_definition_id": .scalar("string"),
                    "kind": .scalar("string"),
                    "page": .scalar("integer"),
                    "per_page": .scalar("integer"),
                    "transaction_hash": .scalar("string"),
                    "transaction_status": .scalar("string"),
                    "accept": .scalar("string"),
                ]
            case .submitAndWait:
                return [
                    "body_base64": .scalar("string"),
                    "hash": .scalar("string"),
                    "status_accept": .scalar("string"),
                    "terminal_statuses": .stringArray,
                    "timeout_ms": .scalar("integer"),
                ]
            }
        }

        fileprivate var alwaysProvidedProperties: Set<String> {
            let names = Set(requestProperties.keys)
            return self == .instructions
                ? names.subtracting(["transaction_hash"])
                : names
        }

        fileprivate func permitsUndeclaredRequestProperty(
            _ name: String
        ) -> Bool {
            switch self {
            case .accountAssets:
                return name == "asset" || name == "scope"
            case .transactionStatus:
                return name == "scope"
            default:
                return false
            }
        }
    }

    struct ToolDiscoveryPage: Equatable {
        let matched: Set<Tool>
        let advertisedNames: Set<String>
        let nextCursor: String?
    }

    fileprivate enum SchemaType {
        case scalar(String)
        case stringArray
    }

    static func initializeRequest(id: String) -> NexusMCPRequest {
        NexusMCPRequest(
            id: id,
            method: "initialize",
            params: .object([
                "protocolVersion": .string(protocolVersion),
                "capabilities": .object([:]),
                "clientInfo": .object([
                    "name": .string("sora-wallet-ios"),
                    "version": .string("1"),
                ]),
            ])
        )
    }

    static func discoveryRequest(
        id: String,
        toolsetVersion: String,
        cursor: String?
    ) throws -> NexusMCPRequest {
        guard NexusTransactionHash.normalized(toolsetVersion) == toolsetVersion
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        var params: [String: NexusJSONValue] = [
            "toolset_version": .string(toolsetVersion),
        ]
        if let cursor {
            guard isCanonicalCursor(cursor) else {
                throw NexusToriiError.mcpContractMismatch
            }
            params["cursor"] = .string(cursor)
        }
        return NexusMCPRequest(
            id: id,
            method: "tools/list",
            params: .object(params)
        )
    }

    static func callRequest(
        id: String,
        tool: Tool,
        arguments: [String: NexusJSONValue]
    ) -> NexusMCPRequest {
        NexusMCPRequest(
            id: id,
            params: .object([
                "name": .string(tool.rawValue),
                "arguments": .object(arguments),
            ])
        )
    }

    static func healthRequest(id: String) -> NexusMCPRequest {
        callRequest(id: id, tool: .health, arguments: [:])
    }

    static func assetDefinitionRequest(id: String) -> NexusMCPRequest {
        callRequest(
            id: id,
            tool: .assetDefinition,
            arguments: [
                "definition_id": .string(
                    NexusAssetDefinitionIdentity.tairaXorDefinitionID
                ),
                "accept": .string("application/json"),
            ]
        )
    }

    static func accountAssetsRequest(
        id: String,
        account: String,
        assetDefinitionID: String,
        limit: Int,
        offset: Int
    ) -> NexusMCPRequest {
        callRequest(
            id: id,
            tool: .accountAssets,
            arguments: [
                "account_id": .string(account),
                // Unpatched Torii advertises `asset_id`, but its GET handler
                // consumes `asset`. Discovery admits only that known drift.
                "asset": .string(assetDefinitionID),
                "limit": .number(String(limit)),
                "offset": .number(String(offset)),
                "scope": .string("global"),
                "accept": .string("application/json"),
            ]
        )
    }

    static func transactionStatusRequest(
        id: String,
        hash: String
    ) throws -> NexusMCPRequest {
        guard NexusTransactionHash.normalized(hash) == hash else {
            throw NexusToriiError.invalidRoute
        }
        return callRequest(
            id: id,
            tool: .transactionStatus,
            arguments: [
                "hash": .string(hash),
                "scope": .string("global"),
                "accept": .string("application/json"),
            ]
        )
    }

    static func instructionsRequest(
        id: String,
        account: String,
        assetDefinitionID: String,
        page: Int,
        perPage: Int,
        transactionHash: String? = nil
    ) throws -> NexusMCPRequest {
        guard page > 0, perPage > 0 else {
            throw NexusToriiError.invalidRoute
        }
        var arguments: [String: NexusJSONValue] = [
            "account": .string(account),
            // `asset_id` is a source-owned balance bucket and would exclude
            // incoming transfers. Use the explicit definition selector.
            "asset_definition_id": .string(assetDefinitionID),
            "kind": .string("Transfer"),
            "transaction_status": .string("committed"),
            "page": .number(String(page)),
            "per_page": .number(String(perPage)),
            "accept": .string("application/json"),
        ]
        if let transactionHash {
            guard NexusTransactionHash.normalized(transactionHash) ==
                transactionHash
            else {
                throw NexusToriiError.invalidRoute
            }
            arguments["transaction_hash"] = .string(transactionHash)
        }
        return callRequest(
            id: id,
            tool: .instructions,
            arguments: arguments
        )
    }

    static func toolsetVersion(initialize result: NexusJSONValue) throws
        -> String
    {
        guard
            let root = result.objectValue,
            root["protocolVersion"]?.exactWireStringValue == protocolVersion,
            let capabilities = root["capabilities"]?.objectValue,
            let tools = capabilities["tools"]?.objectValue,
            let version = tools["toolsetVersion"]?.exactWireStringValue,
            NexusTransactionHash.normalized(version) == version
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        if let server = root["serverInfo"]?.objectValue,
           let name = server["name"]?.exactWireStringValue,
           name != serverName
        {
            throw NexusToriiError.mcpContractMismatch
        }
        return version
    }

    static func validateToolPage(
        _ result: NexusJSONValue,
        tools requiredTools: Set<Tool>,
        expectedToolsetVersion: String
    ) throws -> ToolDiscoveryPage {
        guard
            !requiredTools.isEmpty,
            let root = result.objectValue,
            root["listChanged"]?.boolValue == false,
            root["toolsetVersion"]?.exactWireStringValue ==
                expectedToolsetVersion,
            let advertised = root["tools"]?.arrayValue
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        var advertisedNames = Set<String>()
        var matched = Set<Tool>()
        for value in advertised {
            guard
                let descriptor = value.objectValue,
                let name = descriptor["name"]?.exactWireStringValue,
                !name.isEmpty,
                name == name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                name.utf8.count <= 256,
                advertisedNames.insert(name).inserted
            else {
                throw NexusToriiError.mcpContractMismatch
            }
            guard
                let tool = Tool(rawValue: name),
                requiredTools.contains(tool)
            else {
                continue
            }
            try validateDescriptor(descriptor, for: tool)
            matched.insert(tool)
        }
        let nextCursor: String?
        switch root["nextCursor"] {
        case .some(.null):
            nextCursor = nil
        case let .some(.string(cursor)) where isCanonicalCursor(cursor):
            nextCursor = cursor
        default:
            throw NexusToriiError.mcpContractMismatch
        }
        return ToolDiscoveryPage(
            matched: matched,
            advertisedNames: advertisedNames,
            nextCursor: nextCursor
        )
    }

    private static func validateDescriptor(
        _ descriptor: [String: NexusJSONValue],
        for tool: Tool
    ) throws {
        guard
            let input = descriptor["inputSchema"]?.objectValue,
            input["type"]?.exactWireStringValue == "object",
            let properties = input["properties"]?.objectValue,
            let output = descriptor["outputSchema"]?.objectValue,
            output["type"]?.exactWireStringValue == "object"
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        let admitsAdditionalProperties =
            input["additionalProperties"]?.boolValue == true
        for (name, expectedType) in tool.requestProperties {
            guard let property = properties[name] else {
                guard
                    admitsAdditionalProperties,
                    tool.permitsUndeclaredRequestProperty(name)
                else {
                    throw NexusToriiError.mcpContractMismatch
                }
                continue
            }
            guard validates(property, as: expectedType) else {
                throw NexusToriiError.mcpContractMismatch
            }
        }
        let requiredNames = try schemaRequiredNames(input["required"])
        guard requiredNames.isSubset(of: tool.alwaysProvidedProperties)
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        if tool == .submitAndWait,
           !requiredNames.contains("body_base64")
        {
            throw NexusToriiError.mcpContractMismatch
        }
    }

    private static func validates(
        _ value: NexusJSONValue?,
        as expected: SchemaType
    ) -> Bool {
        guard let schema = value?.objectValue else {
            return false
        }
        switch expected {
        case let .scalar(type):
            return schema["type"]?.exactWireStringValue == type
        case .stringArray:
            return schema["type"]?.exactWireStringValue == "array" &&
                schema["items"]?.objectValue?["type"]?
                    .exactWireStringValue == "string"
        }
    }

    private static func schemaRequiredNames(
        _ value: NexusJSONValue?
    ) throws -> Set<String> {
        guard let value else {
            return []
        }
        guard let array = value.arrayValue else {
            throw NexusToriiError.mcpContractMismatch
        }
        var names = Set<String>()
        for item in array {
            guard
                let name = item.exactWireStringValue,
                !name.isEmpty,
                names.insert(name).inserted
            else {
                throw NexusToriiError.mcpContractMismatch
            }
        }
        return names
    }

    private static func isCanonicalCursor(_ value: String) -> Bool {
        value.range(
            of: #"^[1-9][0-9]{0,5}$"#,
            options: .regularExpression
        ) != nil
    }
}

/// Minamoto compatibility contract for its legacy indexed account-history
/// projection. Public Taira never discovers or calls this tool.
enum NexusMCPAccountHistoryContract {
    static let protocolVersion = "2025-06-18"
    static let serverName = "iroha-torii-mcp"
    static let toolName = "iroha.accounts.history"

    struct ToolsetSnapshot: Equatable {
        let version: String
        let count: Int
    }

    static func toolsetSnapshot(
        initialize result: NexusJSONValue
    ) throws -> ToolsetSnapshot {
        guard
            let root = result.objectValue,
            Set(root.keys) == ["capabilities", "protocolVersion", "serverInfo"],
            root["protocolVersion"]?.exactWireStringValue == protocolVersion,
            let server = root["serverInfo"]?.objectValue,
            Set(server.keys) == ["name", "version"],
            server["name"]?.exactWireStringValue == serverName,
            let serverVersion = server["version"]?.exactWireStringValue,
            !serverVersion.isEmpty,
            serverVersion.utf8.count <= 128,
            let capabilities = root["capabilities"]?.objectValue,
            Set(capabilities.keys) == ["tools"],
            let tools = capabilities["tools"]?.objectValue,
            Set(tools.keys) == ["count", "listChanged", "toolsetVersion"],
            let count = canonicalPositiveInteger(tools["count"]),
            count <= 1_024,
            tools["listChanged"]?.boolValue == false,
            let version = tools["toolsetVersion"]?.exactWireStringValue,
            NexusTransactionHash.normalized(version) == version
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        return ToolsetSnapshot(version: version, count: Int(count))
    }

    static func validateToolList(_ result: NexusJSONValue) throws -> Int {
        guard
            let root = result.objectValue,
            Set(root.keys) == ["listChanged", "nextCursor", "tools"],
            root["listChanged"]?.boolValue == false,
            root["nextCursor"] == .null,
            let listed = root["tools"]?.arrayValue,
            (1 ... 1_024).contains(listed.count)
        else {
            throw NexusToriiError.mcpContractMismatch
        }
        let matches = listed.compactMap { value -> [String: NexusJSONValue]? in
            guard
                let object = value.objectValue,
                object["name"]?.exactWireStringValue == toolName
            else {
                return nil
            }
            return object
        }
        guard matches.count == 1 else {
            throw NexusToriiError.mcpContractMismatch
        }
        try validateTool(matches[0])
        return listed.count
    }

    private static func validateTool(
        _ tool: [String: NexusJSONValue]
    ) throws {
        guard
            Set(tool.keys) == [
                "description", "inputSchema", "name", "outputSchema",
            ],
            let description = tool["description"]?.exactWireStringValue,
            !description.isEmpty,
            description.utf8.count <= 2_048,
            let input = tool["inputSchema"]?.objectValue,
            input["type"]?.exactWireStringValue == "object",
            input["additionalProperties"]?.boolValue == false,
            hasSemanticKeys(
                input,
                exactly: ["additionalProperties", "properties", "type"]
            ),
            let properties = input["properties"]?.objectValue,
            Set(properties.keys) == [
                "accept", "account_id", "asset_id", "headers", "limit",
                "offset", "path", "query",
            ],
            hasScalarType("string", properties["accept"]),
            hasScalarType("string", properties["account_id"]),
            hasScalarType("string", properties["asset_id"]),
            hasClosedEmptyObjectType(properties["headers"]),
            hasScalarType("integer", properties["limit"]),
            hasScalarType("integer", properties["offset"]),
            hasClosedEmptyObjectType(properties["query"]),
            validatePathSchema(properties["path"]),
            let output = tool["outputSchema"]?.objectValue,
            output["type"]?.exactWireStringValue == "object",
            output["additionalProperties"]?.boolValue == true,
            hasSemanticKeys(
                output,
                exactly: ["additionalProperties", "properties", "type"]
            ),
            let outputProperties = output["properties"]?.objectValue,
            Set(outputProperties.keys) == [
                "body", "content_type", "headers", "status",
            ],
            isUnconstrainedSchema(outputProperties["body"]),
            validatesNullableString(outputProperties["content_type"]),
            validatesStringMap(outputProperties["headers"]),
            let status = outputProperties["status"]?.objectValue,
            status["type"]?.exactWireStringValue == "integer",
            hasSemanticKeys(
                status,
                exactly: ["maximum", "minimum", "type"]
            ),
            canonicalPositiveInteger(status["minimum"]) == 100,
            canonicalPositiveInteger(status["maximum"]) == 599
        else {
            throw NexusToriiError.mcpContractMismatch
        }
    }

    /// Descriptions are documentation-only. All validation-bearing JSON Schema
    /// keywords are pinned so a server cannot silently narrow or widen the
    /// wallet's reviewed route while retaining the same tool name.
    private static func hasSemanticKeys(
        _ object: [String: NexusJSONValue],
        exactly expected: Set<String>
    ) -> Bool {
        var keys = Set(object.keys)
        if let description = object["description"] {
            guard
                let text = description.exactWireStringValue,
                !text.isEmpty,
                text.utf8.count <= 2_048
            else {
                return false
            }
            keys.remove("description")
        }
        return keys == expected
    }

    private static func hasScalarType(
        _ expected: String,
        _ value: NexusJSONValue?
    ) -> Bool {
        guard let object = value?.objectValue else {
            return false
        }
        return object["type"]?.exactWireStringValue == expected &&
            hasSemanticKeys(object, exactly: ["type"])
    }

    private static func hasClosedEmptyObjectType(
        _ value: NexusJSONValue?
    ) -> Bool {
        guard let object = value?.objectValue else {
            return false
        }
        return object["type"]?.exactWireStringValue == "object" &&
            object["additionalProperties"]?.boolValue == false &&
            hasSemanticKeys(
                object,
                exactly: ["additionalProperties", "type"]
            )
    }

    private static func isUnconstrainedSchema(
        _ value: NexusJSONValue?
    ) -> Bool {
        guard let object = value?.objectValue else {
            return false
        }
        return hasSemanticKeys(object, exactly: [])
    }

    private static func validatesNullableString(
        _ value: NexusJSONValue?
    ) -> Bool {
        guard
            let object = value?.objectValue,
            hasSemanticKeys(object, exactly: ["oneOf"]),
            let choices = object["oneOf"]?.arrayValue,
            choices.count == 2
        else {
            return false
        }
        let types = choices.compactMap { choice -> String? in
            guard
                let schema = choice.objectValue,
                hasSemanticKeys(schema, exactly: ["type"])
            else {
                return nil
            }
            return schema["type"]?.exactWireStringValue
        }
        return types.count == 2 && Set(types) == ["null", "string"]
    }

    private static func validatesStringMap(
        _ value: NexusJSONValue?
    ) -> Bool {
        guard
            let object = value?.objectValue,
            object["type"]?.exactWireStringValue == "object",
            hasSemanticKeys(
                object,
                exactly: ["additionalProperties", "type"]
            ),
            hasScalarType("string", object["additionalProperties"])
        else {
            return false
        }
        return true
    }

    private static func validatePathSchema(
        _ value: NexusJSONValue?
    ) -> Bool {
        guard
            let object = value?.objectValue,
            object["type"]?.exactWireStringValue == "object",
            object["additionalProperties"]?.boolValue == false,
            hasSemanticKeys(
                object,
                exactly: [
                    "additionalProperties", "properties", "required", "type",
                ]
            ),
            let required = object["required"]?.arrayValue,
            required == [.string("account_id")],
            let properties = object["properties"]?.objectValue,
            Set(properties.keys) == ["account_id"],
            hasScalarType("string", properties["account_id"])
        else {
            return false
        }
        return true
    }

    private static func canonicalPositiveInteger(
        _ value: NexusJSONValue?
    ) -> UInt64? {
        guard
            let value,
            case let .number(raw) = value,
            raw.range(
                of: #"^[1-9][0-9]{0,19}$"#,
                options: .regularExpression
            ) != nil,
            let parsed = UInt64(raw)
        else {
            return nil
        }
        return parsed
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
        requiresFanout: Bool = false,
        expectedContentType: String = "application/json",
        requiresObjectBody: Bool = true
    ) throws -> NexusJSONValue {
        guard
            let direct = result.objectValue,
            direct["body"] == nil,
            direct["items"] == nil,
            let structured = direct["structuredContent"]?.objectValue,
            let rawHeaders = structured["headers"]?.objectValue,
            let statusValue = structured["status"],
            case let .number(statusRaw) = statusValue,
            let status = Int(statusRaw),
            String(status) == statusRaw
        else {
            throw NexusToriiError.invalidResponse
        }
        var headers: [String: String] = [:]
        for (name, value) in rawHeaders {
            guard
                !name.isEmpty,
                name == name.trimmingCharacters(in: .whitespacesAndNewlines),
                name.utf8.count <= 128,
                name.unicodeScalars.allSatisfy({
                    (48 ... 57).contains($0.value) ||
                        (65 ... 90).contains($0.value) ||
                        (97 ... 122).contains($0.value) ||
                        $0 == "-"
                }),
                case let .string(raw) = value,
                raw == raw.trimmingCharacters(in: .whitespacesAndNewlines),
                raw.utf8.count <= 4_096
            else {
                throw NexusToriiError.invalidResponse
            }
            let normalizedName = name.lowercased()
            guard headers.updateValue(raw, forKey: normalizedName) == nil else {
                throw NexusToriiError.invalidResponse
            }
        }
        // Error responses can carry their deployment diagnosis only in the
        // embedded routed-read headers.
        try NexusToriiClient.validateFanoutHeaderValues(
            { headers[$0] },
            requiresFanout: false
        )
        if !(200 ... 299).contains(status) {
            if try NexusToriiDeploymentHealthContract.isRouteUnavailable(
                rejectCode: headers["x-iroha-reject-code"],
                body: structured["body"]
            ) {
                throw NexusToriiError.deploymentUnavailable
            }
            throw NexusToriiError.server
        }
        guard
            direct["isError"]?.boolValue == false,
            let contentTypeValue = structured["content_type"],
            case let .string(contentType) = contentTypeValue,
            NexusToriiMediaTypeContract.matches(
                contentType,
                expected: expectedContentType
            ),
            structured["items"] == nil
        else {
            throw NexusToriiError.invalidResponse
        }
        if requiresObjectBody {
            guard structured["body"]?.objectValue != nil else {
                throw NexusToriiError.invalidResponse
            }
        } else {
            guard structured["body"]?.exactWireStringValue != nil else {
                throw NexusToriiError.invalidResponse
            }
        }
        // Some curated MCP routes legitimately emit no fanout family. An
        // account-history projection opts into the stricter contract: every
        // fanout count must be present and all attempted routes must have
        // succeeded before the embedded body is trusted.
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
    let sourceItemIDs: [String]
    let total: UInt64
    let hasMore: Bool
    let querySource: String
    let indexedHeight: UInt64?
    let indexedBlockHash: String?
}

struct NexusTairaTransferHistoryPage {
    let items: [NexusTransferHistoryItem]
    let sourceItemCount: Int
    let sourceItemIDs: [String]
    let page: UInt64
    let perPage: UInt64
    let totalPages: UInt64
    let totalItems: UInt64

    func validate(expectedPage: Int, maximumPageSize: Int) throws {
        guard
            expectedPage > 0,
            maximumPageSize > 0,
            page == UInt64(expectedPage),
            perPage == UInt64(maximumPageSize),
            sourceItemIDs.count == sourceItemCount,
            Set(sourceItemIDs).count == sourceItemIDs.count,
            (totalPages == 0) == (totalItems == 0),
            page <= max(totalPages, 1),
            totalPages == totalItems.dividedRoundingUp(by: perPage)
        else {
            throw NexusToriiError.invalidResponse
        }
        let (precedingItemCount, overflow) = (page - 1)
            .multipliedReportingOverflow(by: perPage)
        guard !overflow, precedingItemCount <= totalItems else {
            throw NexusToriiError.invalidResponse
        }
        let expectedItemCount = min(
            perPage,
            totalItems - precedingItemCount
        )
        guard
            let canonicalSourceItemCount = UInt64(exactly: sourceItemCount),
            canonicalSourceItemCount == expectedItemCount
        else {
            throw NexusToriiError.invalidResponse
        }
    }
}

private extension UInt64 {
    func dividedRoundingUp(by divisor: UInt64) -> UInt64 {
        guard self > 0 else { return 0 }
        return 1 + (self - 1) / divisor
    }
}

/// Parser for the current `iroha.instructions.list` explorer projection.
enum NexusTairaTransferHistoryParser {
    static func page(
        result: NexusJSONValue,
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> NexusTairaTransferHistoryPage {
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        guard
            let structured = result.objectValue,
            let body = structured["body"]?.objectValue,
            let sourceItems = body["items"]?.arrayValue,
            let pagination = body["pagination"]?.objectValue,
            let page = canonicalUInt64(pagination["page"]),
            let perPage = canonicalUInt64(pagination["per_page"]),
            perPage > 0,
            let totalPages = canonicalUInt64(pagination["total_pages"]),
            let totalItems = canonicalUInt64(pagination["total_items"]),
            UInt64(sourceItems.count) <= totalItems
        else {
            throw NexusToriiError.invalidResponse
        }

        var items: [NexusTransferHistoryItem] = []
        var sourceItemIDs: [String] = []
        for value in sourceItems {
            guard let instruction = value.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            let parsed = try parseInstruction(
                instruction,
                configuration: configuration,
                account: canonicalAccount,
                assetDefinitionID: assetDefinitionID
            )
            guard
                let rawHash = instruction["transaction_hash"]?
                    .exactWireStringValue,
                let hash = NexusTransactionHash.normalized(rawHash),
                hash == rawHash,
                let index = canonicalUInt64(instruction["index"]),
                index <= UInt64(UInt32.max)
            else {
                throw NexusToriiError.invalidResponse
            }
            sourceItemIDs.append("\(hash):\(index)")
            items.append(contentsOf: parsed)
        }
        guard Set(sourceItemIDs).count == sourceItemIDs.count else {
            throw NexusToriiError.invalidResponse
        }
        return NexusTairaTransferHistoryPage(
            items: items,
            sourceItemCount: sourceItems.count,
            sourceItemIDs: sourceItemIDs,
            page: page,
            perPage: perPage,
            totalPages: totalPages,
            totalItems: totalItems
        )
    }

    private static func parseInstruction(
        _ instruction: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> [NexusTransferHistoryItem] {
        guard
            let status = exactString(
                instruction["transaction_status"],
                maximumBytes: 32
            ),
            status.lowercased() == "committed",
            let kind = exactString(instruction["kind"], maximumBytes: 64),
            let rawHash = exactString(
                instruction["transaction_hash"],
                maximumBytes: 64
            ),
            let hash = NexusTransactionHash.normalized(rawHash),
            hash == rawHash,
            let timestamp = parseTimestamp(
                instruction["created_at"]?.exactWireStringValue
            ),
            timestamp > 0,
            let block = canonicalUInt64(instruction["block"]),
            block > 0,
            let authority = instruction["authority"]?.exactWireStringValue,
            (try? IrohaAddressCodec.parse(
                authority,
                expectedDiscriminant: configuration.i105Discriminant
            )) != nil
        else {
            throw NexusToriiError.invalidResponse
        }
        guard kind == "Transfer" else {
            throw NexusToriiError.invalidResponse
        }
        guard
            let box = instruction["box"]?.objectValue,
            let json = box["json"]?.objectValue,
            json["kind"]?.exactWireStringValue == "Transfer",
            let payload = json["payload"]?.objectValue,
            let variant = payload["variant"]?.exactWireStringValue
        else {
            throw NexusToriiError.invalidResponse
        }

        let transfers: [ParsedTransfer]
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
            guard let value = payload["value"]?.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            let entries = ["entries", "transfers", "items"].lazy
                .compactMap { value[$0]?.arrayValue }
                .first
            guard let entries else {
                throw NexusToriiError.invalidResponse
            }
            transfers = try entries.compactMap { entry in
                guard let object = entry.objectValue else {
                    throw NexusToriiError.invalidResponse
                }
                guard
                    firstExactString(
                        in: object,
                        keys: [
                            "asset_definition", "assetDefinition",
                            "asset_definition_id",
                        ]
                    ) == assetDefinitionID
                else {
                    return nil
                }
                return try parseTransfer(
                    object,
                    configuration: configuration,
                    account: account,
                    assetDefinitionID: assetDefinitionID
                )
            }
        default:
            throw NexusToriiError.invalidResponse
        }
        guard !transfers.isEmpty else {
            throw NexusToriiError.invalidResponse
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

    private struct ParsedTransfer {
        let amount: PIQuantity
        let sender: String
        let receiver: String
    }

    private static func parseTransfer(
        _ value: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> ParsedTransfer? {
        let source = firstExactString(
            in: value,
            keys: [
                "source", "source_id", "asset", "asset_id",
                "asset_definition", "assetDefinition",
                "asset_definition_id",
            ]
        )
        let embeddedSourceAccount: String?
        if source == nil || source == assetDefinitionID {
            embeddedSourceAccount = nil
        } else if let source,
                  source.hasPrefix("\(assetDefinitionID)#")
        {
            let suffix = String(source.dropFirst(assetDefinitionID.count + 1))
            guard !suffix.isEmpty, !suffix.contains("#") else {
                throw NexusToriiError.invalidResponse
            }
            embeddedSourceAccount = suffix
        } else {
            return nil
        }
        guard
            let destination = firstExactString(
                in: value,
                keys: [
                    "destination", "destination_id", "to", "account_id",
                ]
            ),
            let rawAmount = ["object", "amount", "quantity", "value"].lazy
                .compactMap({ value[$0] }).first
        else {
            throw NexusToriiError.invalidResponse
        }
        let explicitSource = firstExactString(
            in: value,
            keys: ["source_account", "from", "account"]
        )
        let canonicalDestination = try IrohaAddressCodec.parse(
            destination,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        let canonicalExplicitSource = try explicitSource.map {
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
        if let canonicalExplicitSource, let canonicalEmbeddedSource,
           canonicalExplicitSource != canonicalEmbeddedSource
        {
            throw NexusToriiError.invalidResponse
        }
        let canonicalSource = canonicalExplicitSource ?? canonicalEmbeddedSource
        let incoming = canonicalDestination == account
        let outgoing = canonicalSource == account
        guard incoming || outgoing else {
            return nil
        }
        let amount = try parseAmount(
            rawAmount,
            maximumScale: NexusAmountPolicy.maximumScale(
                for: configuration.networkId
            )
        )
        guard let sender = outgoing ? account : canonicalSource else {
            throw NexusToriiError.invalidResponse
        }
        return ParsedTransfer(
            amount: amount,
            sender: sender,
            receiver: incoming ? account : canonicalDestination
        )
    }

    private static func parseAmount(
        _ value: NexusJSONValue,
        maximumScale: Int
    ) throws -> PIQuantity {
        let raw: String?
        if let string = value.exactWireStringValue {
            raw = string
        } else if let object = value.objectValue {
            let scaleText = object["scale"]?.exactWireStringValue ??
                canonicalUInt64(object["scale"]).map(String.init)
            let mantissa = ["value", "amount", "mantissa"].lazy
                .compactMap { object[$0]?.exactWireStringValue }.first
            if
                let scaleText,
                let scale = Int(scaleText),
                (0 ... maximumScale).contains(scale),
                let mantissa,
                mantissa.range(
                    of: #"^[0-9]+$"#,
                    options: .regularExpression
                ) != nil
            {
                raw = decimalString(mantissa: mantissa, scale: scale)
            } else {
                raw = nil
            }
        } else {
            raw = nil
        }
        guard
            let raw,
            raw.utf8.count <= PIQuantity.maximumWireBytes,
            let exact = NexusExactDecimal(raw),
            exact.unscaled > 0,
            exact.scale <= maximumScale
        else {
            throw NexusToriiError.invalidResponse
        }
        return try PIQuantity(raw)
    }

    private static func decimalString(
        mantissa: String,
        scale: Int
    ) -> String {
        guard scale > 0 else { return mantissa }
        if mantissa.count <= scale {
            return "0." + String(repeating: "0", count: scale - mantissa.count) +
                mantissa
        }
        let split = mantissa.index(mantissa.endIndex, offsetBy: -scale)
        return "\(mantissa[..<split]).\(mantissa[split...])"
    }

    private static func parseTimestamp(_ value: String?) -> Int64? {
        guard let value, !value.isEmpty, value.utf8.count <= 64 else {
            return nil
        }
        if value.unicodeScalars.allSatisfy({ (48 ... 57).contains($0.value) }),
           let integer = Int64(value)
        {
            guard integer < 10_000_000_000 else {
                return integer
            }
            let multiplied = integer.multipliedReportingOverflow(by: 1_000)
            return multiplied.overflow ? nil : multiplied.partialValue
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: value) ?? plain.date(from: value)
        else {
            return nil
        }
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds > 0,
              milliseconds <= Double(Int64.max)
        else {
            return nil
        }
        return Int64(milliseconds.rounded())
    }

    private static func firstExactString(
        in object: [String: NexusJSONValue],
        keys: [String]
    ) -> String? {
        keys.lazy.compactMap {
            exactString(object[$0], maximumBytes: 8_192)
        }.first
    }

    private static func exactString(
        _ value: NexusJSONValue?,
        maximumBytes: Int
    ) -> String? {
        guard
            let string = value?.exactWireStringValue,
            !string.isEmpty,
            string == string.trimmingCharacters(in: .whitespacesAndNewlines),
            string.utf8.count <= maximumBytes
        else {
            return nil
        }
        return string
    }

    private static func canonicalUInt64(
        _ value: NexusJSONValue?
    ) -> UInt64? {
        guard let value, case let .number(raw) = value else {
            return nil
        }
        guard
            raw == "0" || raw.range(
                of: #"^[1-9][0-9]{0,19}$"#,
                options: .regularExpression
            ) != nil
        else {
            return nil
        }
        return UInt64(raw)
    }
}

enum NexusTransferHistoryParser {
    private static let allowedItemKeys: Set<String> = [
        "id", "source", "type", "timestamp_ms", "status", "result_ok",
        "direction", "account_id", "counterparty_account_id", "asset_id",
        "asset_definition_id", "amount", "tx_hash", "operation_id",
        "expires_at_ms", "finalized_at_ms", "requesting_fi_id",
    ]
    private static let requiredItemKeys: Set<String> = [
        "id", "source", "type", "status", "direction", "account_id",
    ]
    private static let transferForbiddenKeys: Set<String> = [
        "operation_id", "expires_at_ms", "finalized_at_ms",
        "requesting_fi_id",
    ]

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
        let baseKeys: Set<String> = [
            "items", "total", "has_more", "count_mode", "query_source",
        ]
        guard
            let sourceItems = body["items"]?.arrayValue,
            let total = canonicalUInt64(body["total"]),
            let hasMore = body["has_more"]?.boolValue,
            body["count_mode"]?.exactWireStringValue == "exact",
            let querySource = body["query_source"]?.exactWireStringValue,
            ["account_history_index", "account_history_fanout"].contains(
                querySource
            ),
            UInt64(sourceItems.count) <= total
        else {
            throw NexusToriiError.invalidResponse
        }
        let indexedHeight: UInt64?
        let indexedBlockHash: String?
        if querySource == "account_history_index" {
            guard
                Set(body.keys) == baseKeys.union([
                    "indexed_height", "indexed_block_hash",
                ]),
                let height = canonicalUInt64(body["indexed_height"]),
                height > 0,
                let rawHash = body["indexed_block_hash"]?
                    .exactWireStringValue,
                NexusTransactionHash.normalized(rawHash) == rawHash
            else {
                throw NexusToriiError.invalidResponse
            }
            indexedHeight = height
            indexedBlockHash = rawHash
        } else {
            guard
                Set(body.keys) == baseKeys,
                !hasMore,
                UInt64(sourceItems.count) == total
            else {
                throw NexusToriiError.invalidResponse
            }
            indexedHeight = nil
            indexedBlockHash = nil
        }

        var sourceItemIDs: [String] = []
        let items = try sourceItems.compactMap { value -> NexusTransferHistoryItem? in
            guard let object = value.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            let parsed = try parseItem(
                object,
                configuration: configuration,
                account: canonicalAccount,
                assetDefinitionID: assetDefinitionID
            )
            guard let id = object["id"]?.exactWireStringValue else {
                throw NexusToriiError.invalidResponse
            }
            sourceItemIDs.append(id)
            return parsed
        }
        return NexusTransferHistoryPage(
            items: items,
            sourceItemCount: sourceItems.count,
            sourceItemIDs: sourceItemIDs,
            total: total,
            hasMore: hasMore,
            querySource: querySource,
            indexedHeight: indexedHeight,
            indexedBlockHash: indexedBlockHash
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
                    object["type"]?.exactWireStringValue == "text"
                else {
                    return nil
                }
                return object["text"]?.exactWireStringValue
            }).first,
            let decoded = try? NexusStrictJSONAdmission.decode(
                NexusJSONValue.self,
                from: Data(text.utf8),
                using: JSONDecoder()
            ),
            let object = decoded.objectValue
        else {
            throw NexusToriiError.invalidResponse
        }
        return object
    }

    private static func parseItem(
        _ object: [String: NexusJSONValue],
        configuration: NexusNetworkConfiguration,
        account: String,
        assetDefinitionID: String
    ) throws -> NexusTransferHistoryItem? {
        guard
            requiredItemKeys.isSubset(of: Set(object.keys)),
            Set(object.keys).isSubset(of: allowedItemKeys),
            let id = boundedString(object["id"], maximumBytes: 4_096),
            !id.isEmpty,
            object["source"]?.exactWireStringValue == "transaction",
            let type = boundedString(object["type"], maximumBytes: 64),
            let status = boundedString(object["status"], maximumBytes: 32),
            let direction = boundedString(
                object["direction"],
                maximumBytes: 16
            ),
            ["incoming", "outgoing", "self", "affected"].contains(
                direction
            ),
            let rawAccount = boundedString(
                object["account_id"],
                maximumBytes: 4_096
            ),
            let itemAccount = try? IrohaAddressCodec.parse(
                rawAccount,
                expectedDiscriminant: configuration.i105Discriminant
            ).i105,
            itemAccount == account
        else {
            throw NexusToriiError.invalidResponse
        }
        guard
            ["TRANSFER", "RAW_ON_CHAIN"].contains(type),
            transferForbiddenKeys.isDisjoint(with: Set(object.keys)),
            let resultOK = object["result_ok"]?.boolValue,
            (status == "SUCCESS" && resultOK) ||
                (status == "FAILED" && !resultOK)
        else {
            throw NexusToriiError.invalidResponse
        }
        guard
            let timestamp = canonicalInt64(object["timestamp_ms"]),
            timestamp > 0,
            let rawHash = boundedString(object["tx_hash"], maximumBytes: 66),
            let hash = NexusTransactionHash.normalized(rawHash),
            hash == rawHash,
            id.hasPrefix("\(rawHash):\(account):"),
            let sequence = id.split(
                separator: ":",
                maxSplits: 2,
                omittingEmptySubsequences: false
            ).last.map(String.init),
            sequence.range(
                of: #"^(?:0|[1-9][0-9]{0,19})$"#,
                options: .regularExpression
            ) != nil,
            UInt64(sequence) != nil,
            object["asset_definition_id"]?.exactWireStringValue ==
                assetDefinitionID,
            let rawAssetID = boundedString(
                object["asset_id"],
                maximumBytes: 8_192
            ),
            rawAssetID == "\(assetDefinitionID)#\(account)",
            let amountValue = object["amount"]
        else {
            throw NexusToriiError.invalidResponse
        }
        let amount = try parseAmount(amountValue)
        let counterparty = try object["counterparty_account_id"].map {
            guard
                let raw = boundedString($0, maximumBytes: 4_096)
            else {
                throw NexusToriiError.invalidResponse
            }
            return try IrohaAddressCodec.parse(
                raw,
                expectedDiscriminant: configuration.i105Discriminant
            ).i105
        }
        if type == "RAW_ON_CHAIN" {
            guard
                counterparty == nil,
                ["incoming", "outgoing"].contains(direction)
            else {
                throw NexusToriiError.invalidResponse
            }
            return nil
        }
        let sender: String
        let receiver: String
        switch direction {
        case "incoming":
            guard let counterparty, counterparty != account else {
                throw NexusToriiError.invalidResponse
            }
            sender = counterparty
            receiver = account
        case "outgoing":
            guard let counterparty, counterparty != account else {
                throw NexusToriiError.invalidResponse
            }
            sender = account
            receiver = counterparty
        case "self":
            guard counterparty == nil else {
                throw NexusToriiError.invalidResponse
            }
            sender = account
            receiver = account
        default:
            throw NexusToriiError.invalidResponse
        }
        // Failed transactions are useful pagination evidence but never proof
        // of a committed transfer. Validate their complete projection first so
        // malformed failed rows cannot hide behind the filter.
        guard resultOK else {
            return nil
        }
        return NexusTransferHistoryItem(
            transactionHash: hash,
            timestampMilliseconds: timestamp,
            amount: amount,
            sender: sender,
            receiver: receiver
        )
    }

    private static func parseAmount(
        _ value: NexusJSONValue
    ) throws -> PIQuantity {
        guard
            let raw = value.exactWireStringValue,
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

    private static func boundedString(
        _ value: NexusJSONValue?,
        maximumBytes: Int
    ) -> String? {
        guard
            let value = value?.exactWireStringValue,
            !value.isEmpty,
            value.utf8.count <= maximumBytes,
            !value.unicodeScalars.contains(where: {
                $0.value < 0x20 || (0x7F ... 0x9F).contains($0.value)
            })
        else {
            return nil
        }
        return value
    }

    private static func canonicalUInt64(
        _ value: NexusJSONValue?
    ) -> UInt64? {
        guard
            let value,
            case let .number(raw) = value,
            raw == "0" || (
                raw.range(
                    of: #"^[1-9][0-9]{0,19}$"#,
                    options: .regularExpression
                ) != nil && !raw.hasPrefix("0")
            ),
            let parsed = UInt64(raw)
        else {
            return nil
        }
        return parsed
    }

    private static func canonicalInt64(
        _ value: NexusJSONValue?
    ) -> Int64? {
        guard let raw = canonicalUInt64(value), raw <= UInt64(Int64.max) else {
            return nil
        }
        return Int64(raw)
    }
}

/// Minamoto's existing raw-pipeline receipt. Taira never decodes this shape;
/// its current receipt/hash contract is admitted by the MCP parser below.
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

struct NexusTairaAppliedSubmission: Equatable {
    let hash: String
    let blockHeight: Int64
}

enum NexusToriiSubmissionResult: Equatable {
    case submitted(NexusTransactionReceipt)
    case applied(NexusTairaAppliedSubmission)

    func validate(
        expectedHash: String,
        configuration: NexusNetworkConfiguration
    ) throws -> Int64? {
        switch (configuration.networkId, self) {
        case let (.minamoto, .submitted(receipt)):
            try receipt.validate(expectedHash: expectedHash)
            return nil
        case let (.taira, .applied(submission)):
            guard
                let expectedHash = NexusTransactionHash.normalized(
                    expectedHash
                ),
                let returnedHash = NexusTransactionHash.normalized(
                    submission.hash
                ),
                returnedHash == expectedHash,
                submission.blockHeight > 0
            else {
                throw NexusToriiError.transactionHashMismatch
            }
            return submission.blockHeight
        default:
            throw NexusToriiError.invalidResponse
        }
    }
}

/// Exact first-release Taira write contract exposed by Torii's MCP server.
/// Keeping the request and result admission here makes it impossible for the
/// Taira branch to silently fall back to the raw pipeline submission route.
enum NexusTairaTransactionSubmissionContract {
    static let toolName = "iroha.transactions.submit_and_wait"
    static let timeoutMilliseconds: UInt64 = 120_000
    static let requestTimeoutInterval: TimeInterval = 135

    static func request(
        id: String,
        signedNorito: Data,
        expectedHash: String
    ) throws -> NexusMCPRequest {
        NexusMCPRequest(
            id: id,
            params: try callParameters(
                signedNorito: signedNorito,
                expectedHash: expectedHash
            )
        )
    }

    static func callParameters(
        signedNorito: Data,
        expectedHash: String
    ) throws -> NexusJSONValue {
        guard
            !signedNorito.isEmpty,
            let hash = NexusTransactionHash.normalized(expectedHash),
            hash == expectedHash
        else {
            throw NexusToriiError.invalidResponse
        }
        return .object([
            "name": .string(toolName),
            "arguments": .object([
                "body_base64": .string(signedNorito.base64EncodedString()),
                "hash": .string(hash),
                "status_accept": .string("application/json"),
                "terminal_statuses": .array([.string("Applied")]),
                "timeout_ms": .number(String(timeoutMilliseconds))
            ])
        ])
    }

    static func appliedSubmission(
        from result: NexusJSONValue,
        expectedHash: String
    ) throws -> NexusTairaAppliedSubmission {
        guard
            let expectedHash = NexusTransactionHash.normalized(expectedHash),
            let wrapper = result.objectValue,
            Set(wrapper.keys) == ["content", "isError", "structuredContent"],
            let isError = wrapper["isError"]?.boolValue
        else {
            throw NexusToriiError.invalidResponse
        }
        guard !isError else {
            throw NexusToriiError.server
        }
        if
            let structured = wrapper["structuredContent"]?.objectValue,
            let terminalKind = structured["terminal_kind"]?
                .exactWireStringValue,
            ["Rejected", "Expired"].contains(terminalKind)
        {
            throw NexusToriiError.server
        }
        guard
            let content = wrapper["content"]?.arrayValue,
            content.count == 1,
            let contentItem = content.first?.objectValue,
            Set(contentItem.keys) == ["type", "text"],
            contentItem["type"]?.exactWireStringValue == "text",
            let structured = wrapper["structuredContent"]?.objectValue,
            Set(structured.keys) == [
                "attempts", "elapsed_ms", "final", "hash", "status",
                "submit", "terminal_kind", "terminal_statuses"
            ],
            let status = canonicalUInt64(structured["status"]),
            (200 ... 299).contains(status),
            contentItem["text"]?.exactWireStringValue == "http \(status)",
            let attempts = canonicalUInt64(structured["attempts"]),
            attempts > 0,
            canonicalUInt64(structured["elapsed_ms"]) != nil,
            structured["terminal_kind"]?.exactWireStringValue == "Applied",
            structured["terminal_statuses"]?.arrayValue == [
                .string("Applied")
            ],
            let returnedHash = structured["hash"]?.exactWireStringValue
        else {
            throw NexusToriiError.invalidResponse
        }
        try requireHash(returnedHash, equals: expectedHash)

        guard
            let submit = structured["submit"]?.objectValue,
            Set(submit.keys) == ["body", "content_type", "headers", "status"],
            let submitStatus = canonicalUInt64(submit["status"]),
            (200 ... 299).contains(submitStatus),
            let submitHeaders = submit["headers"]?.objectValue,
            let submitHeaderContentType = submitHeaders["content-type"]?
                .exactWireStringValue,
            NexusToriiMediaTypeContract.matches(
                submitHeaderContentType,
                expected: "application/json"
            ),
            let submitHeaderHash = submitHeaders[
                "x-iroha-transaction-hash"
            ]?.exactWireStringValue,
            let submitContentType = submit["content_type"]?
                .exactWireStringValue,
            NexusToriiMediaTypeContract.matches(
                submitContentType,
                expected: "application/json"
            ),
            let submitBody = submit["body"]?.objectValue,
            let receiptPayload = submitBody["payload"]?.objectValue,
            let receiptHash = receiptPayload["tx_hash"]?
                .exactWireStringValue
        else {
            throw NexusToriiError.invalidResponse
        }
        try requireHash(submitHeaderHash, equals: expectedHash)
        try requireHash(receiptHash, equals: expectedHash)
        let submitHashes = try transactionHashes(in: .object(submitBody))
        for hash in submitHashes {
            try requireHash(hash, equals: expectedHash)
        }

        guard
            let final = structured["final"]?.objectValue,
            Set(final.keys) == ["body", "content_type", "headers", "status"],
            let finalStatus = canonicalUInt64(final["status"]),
            finalStatus == status,
            final["headers"]?.objectValue != nil,
            let finalContentType = final["content_type"]?.exactWireStringValue,
            NexusToriiMediaTypeContract.matches(
                finalContentType,
                expected: "application/json"
            ),
            let finalBody = final["body"]?.objectValue,
            let finalHash = finalBody["hash"]?.exactWireStringValue,
            finalBody["scope"]?.exactWireStringValue == "global",
            finalBody["resolved_from"]?.exactWireStringValue == "state",
            let finalStatusBody = finalBody["status"]?.objectValue,
            finalStatusBody["kind"]?.exactWireStringValue == "Applied",
            finalStatusBody["rejection_reason"] == nil ||
                finalStatusBody["rejection_reason"] == .null,
            let blockHeight = canonicalInt64(
                finalStatusBody["block_height"]
            ),
            blockHeight > 0
        else {
            throw NexusToriiError.invalidResponse
        }
        try requireHash(finalHash, equals: expectedHash)
        let finalHashes = try transactionHashes(in: .object(finalBody))
        guard !finalHashes.isEmpty else {
            throw NexusToriiError.invalidResponse
        }
        for hash in finalHashes {
            try requireHash(hash, equals: expectedHash)
        }
        return NexusTairaAppliedSubmission(
            hash: expectedHash,
            blockHeight: blockHeight
        )
    }

    private static func transactionHashes(
        in body: NexusJSONValue
    ) throws -> [String] {
        guard let object = body.objectValue else {
            throw NexusToriiError.invalidResponse
        }
        let hashKeys = [
            "hash", "tx_hash", "tx_hash_hex", "transaction_hash",
            "entrypoint_hash", "signed_transaction_hash"
        ]
        var values: [String] = []
        for key in hashKeys where object[key] != nil {
            guard let value = object[key]?.exactWireStringValue else {
                throw NexusToriiError.invalidResponse
            }
            values.append(value)
        }
        if let payload = object["payload"] {
            guard let payloadObject = payload.objectValue else {
                throw NexusToriiError.invalidResponse
            }
            for key in hashKeys where payloadObject[key] != nil {
                guard
                    let value = payloadObject[key]?.exactWireStringValue
                else {
                    throw NexusToriiError.invalidResponse
                }
                values.append(value)
            }
        }
        return values
    }

    private static func requireHash(
        _ value: String,
        equals expectedHash: String
    ) throws {
        guard NexusTransactionHash.normalized(value) == expectedHash else {
            throw NexusToriiError.transactionHashMismatch
        }
    }

    private static func canonicalUInt64(
        _ value: NexusJSONValue?
    ) -> UInt64? {
        guard let value, case let .number(raw) = value else {
            return nil
        }
        guard
            raw == "0" || raw.range(
                of: #"^[1-9][0-9]{0,19}$"#,
                options: .regularExpression
            ) != nil
        else {
            return nil
        }
        return UInt64(raw)
    }

    private static func canonicalInt64(
        _ value: NexusJSONValue?
    ) -> Int64? {
        guard
            let value = canonicalUInt64(value),
            value <= UInt64(Int64.max)
        else {
            return nil
        }
        return Int64(value)
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
        let isTairaOrigin = isCanonicalTairaOrigin(url)
        switch (method, url.path) {
        case ("GET", _) where !isTairaOrigin:
            return nil
        case ("POST", let path) where path.hasSuffix("/v1/mcp"):
            if isTairaOrigin,
               url != TairaDeploymentBinding.canonicalPublicMcpEndpoint
            {
                throw NexusToriiError.invalidRoute
            }
            return "application/json"
        case ("POST", let path)
            where !isTairaOrigin &&
            path.hasSuffix("/v1/pipeline/transactions"):
            return "application/x-norito"
        default:
            throw NexusToriiError.invalidRoute
        }
    }

    private static func isCanonicalTairaOrigin(_ url: URL) -> Bool {
        let canonical = TairaDeploymentBinding.canonicalToriiBaseURL
        return url.scheme?.lowercased() == canonical.scheme?.lowercased() &&
            url.host?.lowercased() == canonical.host?.lowercased() &&
            url.port == canonical.port
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
    ) throws -> URL {
        guard configuration.networkId != .taira else {
            throw NexusToriiError.invalidRoute
        }
        return configuration.toriiURL
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

    static func validateOuterAvailabilityStatus(
        _ statusCode: Int,
        for url: URL? = nil
    ) throws {
        if statusCode == 404,
           url == TairaDeploymentBinding.canonicalPublicMcpEndpoint
        {
            throw NexusToriiError.mcpNotEnabled
        }
        if statusCode == 502 || statusCode == 503 {
            throw NexusToriiError.deploymentUnavailable
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
            routeLaneID == nil || routedBy == "local",
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
            // Lane/dataspace provenance is meaningful only together with the
            // complete single-route fanout counters validated below. Never
            // accept an otherwise plausible local route identity as partial
            // evidence on a response that did not declare its fanout result.
            guard routeLaneID == nil else {
                throw NexusToriiError.invalidResponse
            }
            if firstFailure == "route_unavailable" {
                throw NexusToriiError.deploymentUnavailable
            }
            guard firstFailure == nil, !requiresFanout else {
                throw NexusToriiError.invalidResponse
            }
            return
        }
        guard
            rawCounts.allSatisfy({ $0 != nil }),
            routedBy != nil
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
            counts[1] <= counts[0],
            counts[2] <= counts[0],
            counts[1] + counts[2] == counts[0],
            counts[3] + counts[4] + counts[5] <= counts[2]
        else {
            throw NexusToriiError.invalidResponse
        }
        if routeLaneID != nil {
            guard
                routedBy == "local",
                counts == [1, 1, 0, 0, 0, 0],
                firstFailure == nil
            else {
                throw NexusToriiError.invalidResponse
            }
            return
        }
        let isComplete = counts[1] == counts[0] &&
            counts.dropFirst(2).allSatisfy({ $0 == 0 })
        if isComplete {
            guard firstFailure == nil else {
                throw NexusToriiError.invalidResponse
            }
            return
        }
        if counts[3] > 0 {
            guard firstFailure == nil || firstFailure == "route_unavailable" else {
                throw NexusToriiError.invalidResponse
            }
            throw NexusToriiError.deploymentUnavailable
        }
        throw NexusToriiError.invalidResponse
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
            configuration.timeoutIntervalForResource = 130
            configuration.waitsForConnectivity = true
            configuration.httpMaximumConnectionsPerHost = 2
            self.session = URLSession(
                configuration: configuration,
                delegate: NexusRedirectRejectingDelegate.shared,
                delegateQueue: nil
            )
        }
    }

    private func decodeResponse<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        try NexusStrictJSONAdmission.decode(
            type,
            from: data,
            using: decoder
        )
    }

    private func decodeMCPBody<Value: Decodable>(
        _ type: Value.Type,
        from structuredResult: NexusJSONValue
    ) throws -> Value {
        guard
            let structured = structuredResult.objectValue,
            let body = structured["body"]
        else {
            throw NexusToriiError.invalidResponse
        }
        return try decodeResponse(type, from: encoder.encode(body))
    }

    func health(configuration: NexusNetworkConfiguration) async throws {
        guard configuration.satisfiesCurrentTairaContract else {
            throw NexusToriiError.invalidRoute
        }
        if configuration.networkId == .taira {
            try await ensureTairaTool(.health, configuration: configuration)
            let response = try await mcp(
                NexusTairaMCPToolContract.healthRequest(id: "taira-health"),
                configuration: configuration
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let structured = try NexusMCPResultContract
                .validateEmbeddedRoute(
                    result,
                    expectedContentType: "text/plain",
                    requiresObjectBody: false
                )
            guard
                let body = structured.objectValue?["body"]?
                    .exactWireStringValue
            else {
                throw NexusToriiError.invalidResponse
            }
            try Self.validateHealthPayload(Data(body.utf8))
            return
        }
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
        guard configuration.satisfiesCurrentTairaContract else {
            throw NexusToriiError.invalidRoute
        }
        let definition: NexusAssetDefinition
        if configuration.networkId == .taira {
            try await ensureTairaTool(
                .assetDefinition,
                configuration: configuration
            )
            let response = try await mcp(
                NexusTairaMCPToolContract.assetDefinitionRequest(
                    id: "taira-xor-definition"
                ),
                configuration: configuration
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let structured = try NexusMCPResultContract
                .validateEmbeddedRoute(result)
            definition = try decodeMCPBody(
                NexusAssetDefinition.self,
                from: structured
            )
        } else {
            definition = try decodeResponse(
                NexusAssetDefinition.self,
                from: await data(
                    request: request(
                        url: try Self.xorAssetDefinitionURL(
                            configuration: configuration
                        ),
                        method: "GET"
                    ),
                    requiresFanout: true
                )
            )
        }
        try NexusAssetDefinitionIdentity.validateXor(
            definition,
            configuration: configuration
        )
        return definition
    }

    func accountAssets(
        account: String,
        configuration: NexusNetworkConfiguration,
        asset: String,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> NexusAccountAssetList {
        guard configuration.satisfiesCurrentTairaContract else {
            throw NexusToriiError.invalidRoute
        }
        let canonicalAccount = try IrohaAddressCodec.parse(
            account,
            expectedDiscriminant: configuration.i105Discriminant
        ).i105
        guard
            (1 ... 500).contains(limit),
            offset >= 0,
            NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
                asset,
                configuration: configuration
            )
        else {
            throw NexusToriiError.invalidRoute
        }
        if configuration.networkId == .taira {
            try await ensureTairaTool(
                .accountAssets,
                configuration: configuration
            )
            let response = try await mcp(
                NexusTairaMCPToolContract.accountAssetsRequest(
                    id: "taira-assets-\(offset)",
                    account: canonicalAccount,
                    assetDefinitionID: asset,
                    limit: limit,
                    offset: offset
                ),
                configuration: configuration
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let structured = try NexusMCPResultContract
                .validateEmbeddedRoute(result, requiresFanout: true)
            let current = try decodeMCPBody(
                NexusTairaAccountAssetPage.self,
                from: structured
            )
            let consumed = Int64(offset) + Int64(current.items.count)
            guard
                current.total >= 0,
                current.total <= 10_000,
                consumed >= Int64(offset),
                consumed <= current.total,
                current.items.count <= limit
            else {
                throw NexusToriiError.invalidResponse
            }
            return NexusAccountAssetList(
                items: current.items,
                hasMore: consumed < current.total,
                countMode: "exact",
                total: current.total
            )
        }

        var components = URLComponents(
            url: configuration.toriiURL
                .appendingPathComponent("v1/accounts")
                .appendingPathComponent(canonicalAccount)
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
        return try decodeResponse(
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
        return try decodeResponse(
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
        guard
            configuration.satisfiesCurrentTairaContract,
            configuration.networkId != .taira
        else {
            throw NexusToriiError.invalidRoute
        }
        try configuration.validate(address: account)
        guard
            (1 ... 100).contains(limit),
            offset >= 0,
            NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
                assetDefinitionID,
                configuration: configuration
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
            NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
                assetDefinitionID,
                configuration: configuration
            ),
            let expectedHash = NexusTransactionHash.normalized(
                transactionHash
            )
        else {
            throw NexusToriiError.invalidRoute
        }

        if configuration.networkId == .taira {
            try await ensureTairaTool(
                .instructions,
                configuration: configuration
            )
            let response = try await mcp(
                NexusTairaMCPToolContract.instructionsRequest(
                    id: "taira-committed-\(expectedHash.prefix(12))",
                    account: canonicalAccount,
                    assetDefinitionID: assetDefinitionID,
                    page: 1,
                    perPage: 100,
                    transactionHash: expectedHash
                ),
                configuration: configuration
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let structured = try NexusMCPResultContract
                .validateEmbeddedRoute(result)
            let page = try NexusTairaTransferHistoryParser.page(
                result: structured,
                configuration: configuration,
                account: canonicalAccount,
                assetDefinitionID: assetDefinitionID
            )
            try page.validate(expectedPage: 1, maximumPageSize: 100)
            guard
                page.totalPages <= 1,
                page.items.allSatisfy({
                    $0.transactionHash == expectedHash
                })
            else {
                throw NexusToriiError.invalidResponse
            }
            return !page.items.isEmpty
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

    /// Reads committed XOR transfers. Taira uses the current explorer
    /// instruction projection; Minamoto retains its legacy indexed history.
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
            NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
                assetDefinitionID,
                configuration: configuration
            )
        else {
            throw NexusToriiError.invalidRoute
        }
        if configuration.networkId == .taira {
            return try await tairaCommittedXorTransfers(
                account: canonicalAccount,
                configuration: configuration,
                assetDefinitionID: assetDefinitionID
            )
        }
        // Minamoto compatibility only. Public Taira never discovers or calls
        // `iroha.accounts.history`.
        try await validateAccountHistoryMCPContract(
            configuration: configuration
        )

        let pageSize = 100
        let maximumPages = 20
        var history: [NexusTransferHistoryItem] = []
        var sourceItemIDs = Set<String>()
        var expectedTotal: UInt64?
        var expectedIndexedHeight: UInt64?
        var expectedIndexedBlockHash: String?
        var expectedQuerySource: String?
        var offset = 0
        for page in 1 ... maximumPages {
            let response = try await mcp(
                NexusMCPRequest(
                    id: "history-\(page)",
                    params: .object([
                        "name": .string("iroha.accounts.history"),
                        "arguments": .object([
                            "account_id": .string(canonicalAccount),
                            "asset_id": .string(assetDefinitionID),
                            "limit": .number(String(pageSize)),
                            "offset": .number(String(offset)),
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
            guard
                expectedTotal.map({ $0 == parsed.total }) ?? true,
                expectedQuerySource.map({ $0 == parsed.querySource }) ?? true,
                expectedIndexedHeight.map({ $0 == parsed.indexedHeight }) ?? true,
                expectedIndexedBlockHash.map({
                    $0 == parsed.indexedBlockHash
                }) ?? true,
                UInt64(offset) <= parsed.total,
                UInt64(parsed.sourceItemCount) <= parsed.total - UInt64(offset),
                parsed.hasMore == (
                    UInt64(offset + parsed.sourceItemCount) < parsed.total
                )
            else {
                throw NexusToriiError.invalidResponse
            }
            expectedTotal = parsed.total
            expectedQuerySource = parsed.querySource
            expectedIndexedHeight = parsed.indexedHeight
            expectedIndexedBlockHash = parsed.indexedBlockHash
            for id in parsed.sourceItemIDs {
                guard sourceItemIDs.insert(id).inserted else {
                    throw NexusToriiError.invalidResponse
                }
            }
            history.append(contentsOf: parsed.items)
            offset += parsed.sourceItemCount
            if parsed.querySource == "account_history_fanout" {
                guard UInt64(offset) == parsed.total else {
                    throw NexusToriiError.invalidResponse
                }
                return history
            }
            if !parsed.hasMore {
                return history
            }
            guard parsed.sourceItemCount > 0 else {
                throw NexusToriiError.invalidResponse
            }
        }
        throw NexusToriiError.invalidResponse
    }

    private func tairaCommittedXorTransfers(
        account: String,
        configuration: NexusNetworkConfiguration,
        assetDefinitionID: String
    ) async throws -> [NexusTransferHistoryItem] {
        try await ensureTairaTool(.instructions, configuration: configuration)
        let pageSize = 100
        let maximumPages = 20
        let maximumItems = pageSize * maximumPages
        var history: [NexusTransferHistoryItem] = []
        var sourceItemIDs = Set<String>()
        var expectedTotalPages: UInt64?
        var expectedTotalItems: UInt64?
        var consumedSourceItems: UInt64 = 0

        for pageNumber in 1 ... maximumPages {
            let response = try await mcp(
                NexusTairaMCPToolContract.instructionsRequest(
                    id: "history-\(pageNumber)",
                    account: account,
                    assetDefinitionID: assetDefinitionID,
                    page: pageNumber,
                    perPage: pageSize
                ),
                configuration: configuration
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let structured = try NexusMCPResultContract
                .validateEmbeddedRoute(result)
            let parsed = try NexusTairaTransferHistoryParser.page(
                result: structured,
                configuration: configuration,
                account: account,
                assetDefinitionID: assetDefinitionID
            )
            try parsed.validate(
                expectedPage: pageNumber,
                maximumPageSize: pageSize
            )
            guard
                parsed.perPage == UInt64(pageSize),
                parsed.totalPages <= UInt64(maximumPages),
                parsed.totalItems <= UInt64(maximumItems),
                expectedTotalPages.map({ $0 == parsed.totalPages }) ?? true,
                expectedTotalItems.map({ $0 == parsed.totalItems }) ?? true,
                consumedSourceItems <= parsed.totalItems,
                UInt64(parsed.sourceItemCount) <=
                    parsed.totalItems - consumedSourceItems
            else {
                throw NexusToriiError.invalidResponse
            }
            expectedTotalPages = parsed.totalPages
            expectedTotalItems = parsed.totalItems
            for id in parsed.sourceItemIDs {
                guard sourceItemIDs.insert(id).inserted else {
                    throw NexusToriiError.invalidResponse
                }
            }
            consumedSourceItems += UInt64(parsed.sourceItemCount)
            history.append(contentsOf: parsed.items)
            guard history.count <= maximumItems else {
                throw NexusToriiError.invalidResponse
            }
            if UInt64(pageNumber) >= parsed.totalPages {
                guard consumedSourceItems == parsed.totalItems else {
                    throw NexusToriiError.invalidResponse
                }
                return history
            }
            guard parsed.sourceItemCount > 0 else {
                throw NexusToriiError.invalidResponse
            }
        }
        throw NexusToriiError.invalidResponse
    }

    private func ensureTairaTool(
        _ tool: NexusTairaMCPToolContract.Tool,
        configuration: NexusNetworkConfiguration
    ) async throws {
        guard
            configuration.networkId == .taira,
            configuration.satisfiesCurrentTairaContract
        else {
            throw NexusToriiError.invalidRoute
        }
        let initialize = try await mcp(
            NexusTairaMCPToolContract.initializeRequest(
                id: "taira-tools-initialize"
            ),
            configuration: configuration
        )
        guard let initializeResult = initialize.result else {
            throw NexusToriiError.mcpContractMismatch
        }
        let version = try NexusTairaMCPToolContract.toolsetVersion(
            initialize: initializeResult
        )
        var cursor: String?
        var seenCursors = Set<String>()
        var advertisedNames = Set<String>()
        for pageIndex in 1 ... 32 {
            let listing = try await mcp(
                NexusTairaMCPToolContract.discoveryRequest(
                    id: "taira-tools-list-\(pageIndex)",
                    toolsetVersion: version,
                    cursor: cursor
                ),
                configuration: configuration
            )
            guard let result = listing.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let page = try NexusTairaMCPToolContract.validateToolPage(
                result,
                tools: [tool],
                expectedToolsetVersion: version
            )
            guard advertisedNames.isDisjoint(with: page.advertisedNames)
            else {
                throw NexusToriiError.mcpContractMismatch
            }
            advertisedNames.formUnion(page.advertisedNames)
            if page.matched.contains(tool) {
                return
            }
            guard let nextCursor = page.nextCursor else {
                throw NexusToriiError.mcpContractMismatch
            }
            guard seenCursors.insert(nextCursor).inserted else {
                throw NexusToriiError.mcpContractMismatch
            }
            cursor = nextCursor
        }
        throw NexusToriiError.mcpContractMismatch
    }

    private func validateAccountHistoryMCPContract(
        configuration: NexusNetworkConfiguration
    ) async throws {
        guard configuration.networkId != .taira else {
            throw NexusToriiError.invalidRoute
        }
        for attempt in 1 ... 2 {
            let before = try await mcpToolsetVersion(
                id: "history-contract-before-\(attempt)",
                configuration: configuration
            )
            let listing = try await mcp(
                NexusMCPRequest(
                    id: "history-contract-tools-\(attempt)",
                    method: "tools/list",
                    params: .object([:])
                ),
                configuration: configuration
            )
            guard let listed = listing.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let listedCount = try NexusMCPAccountHistoryContract
                .validateToolList(listed)
            let after = try await mcpToolsetVersion(
                id: "history-contract-after-\(attempt)",
                configuration: configuration
            )
            if before == after, listedCount == before.count {
                return
            }
        }
        throw NexusToriiError.mcpContractMismatch
    }

    private func mcpToolsetVersion(
        id: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusMCPAccountHistoryContract.ToolsetSnapshot {
        let response = try await mcp(
            NexusMCPRequest(
                id: id,
                method: "initialize",
                params: .object([
                    "protocolVersion": .string(
                        NexusMCPAccountHistoryContract.protocolVersion
                    ),
                    "capabilities": .object([:]),
                    "clientInfo": .object([
                        "name": .string("sora-wallet-ios"),
                        "version": .string("1")
                    ])
                ])
            ),
            configuration: configuration
        )
        guard let result = response.result else {
            throw NexusToriiError.mcpContractMismatch
        }
        return try NexusMCPAccountHistoryContract.toolsetSnapshot(
            initialize: result
        )
    }

    func submit(
        signedNorito: Data,
        idempotencyKey: UUID,
        expectedHash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusToriiSubmissionResult {
        guard configuration.satisfiesCurrentTairaContract else {
            throw NexusToriiError.invalidRoute
        }
        if configuration.networkId == .taira {
            try await ensureTairaTool(
                .submitAndWait,
                configuration: configuration
            )
            let requestID = "submit-\(UUID().uuidString.lowercased())"
            let response = try await mcp(
                NexusTairaTransactionSubmissionContract.request(
                    id: requestID,
                    signedNorito: signedNorito,
                    expectedHash: expectedHash
                ),
                configuration: configuration,
                timeoutInterval:
                    NexusTairaTransactionSubmissionContract
                        .requestTimeoutInterval
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            return .applied(
                try NexusTairaTransactionSubmissionContract
                    .appliedSubmission(
                        from: result,
                        expectedHash: expectedHash
                    )
            )
        }
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
        return .submitted(
            try decodeResponse(
                NexusTransactionReceipt.self,
                from: await data(request: transactionRequest)
            )
        )
    }

    func status(
        hash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusPipelineStatus {
        guard configuration.satisfiesCurrentTairaContract else {
            throw NexusToriiError.invalidRoute
        }
        guard let normalizedHash = NexusTransactionHash.normalized(hash) else {
            throw NexusToriiError.invalidRoute
        }
        if configuration.networkId == .taira {
            try await ensureTairaTool(
                .transactionStatus,
                configuration: configuration
            )
            let response = try await mcp(
                NexusTairaMCPToolContract.transactionStatusRequest(
                    id: "taira-status-\(normalizedHash.prefix(12))",
                    hash: normalizedHash
                ),
                configuration: configuration
            )
            guard let result = response.result else {
                throw NexusToriiError.mcpContractMismatch
            }
            let structured = try NexusMCPResultContract
                .validateEmbeddedRoute(result)
            return try decodeMCPBody(
                NexusPipelineStatus.self,
                from: structured
            )
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
        return try decodeResponse(
            NexusPipelineStatus.self,
            from: await data(request: request(url: url, method: "GET"))
        )
    }

    private func mcp(
        _ payload: NexusMCPRequest,
        configuration: NexusNetworkConfiguration,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> NexusMCPResponse {
        guard configuration.satisfiesCurrentTairaContract else {
            throw NexusToriiError.invalidRoute
        }
        guard
            payload.id.range(
                of: #"^[A-Za-z0-9._:-]{1,64}$"#,
                options: .regularExpression
            ) != nil
        else {
            throw NexusToriiError.invalidRoute
        }
        let endpoint = configuration.networkId == .taira ?
            TairaDeploymentBinding.canonicalPublicMcpEndpoint :
            configuration.toriiURL.appendingPathComponent("v1/mcp")
        var mcpRequest = request(
            url: endpoint,
            method: "POST"
        )
        if let timeoutInterval {
            mcpRequest.timeoutInterval = timeoutInterval
        }
        mcpRequest.httpBody = try encoder.encode(payload)
        mcpRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        let response = try decodeResponse(
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
        // The fixed first-release origin is checked before URLSession observes
        // any Taira request. Alternate roots never become transport fallbacks.
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
        try Self.validateOuterAvailabilityStatus(
            response.statusCode,
            for: requestURL
        )
        let isSuccessful = (200 ... 299).contains(response.statusCode)
        let maximumResponseBytes = isSuccessful ? responseLimit : 64 * 1_024
        try Self.validateResponseLength(
            response.expectedContentLength,
            maximumBytes: maximumResponseBytes
        )
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
        } else {
            // A failed routed read may carry the deployment diagnosis only in
            // Torii headers. Preserve that typed signal before reading its
            // bounded error body.
            try Self.validateFanoutHeaders(response)
        }
        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        for try await byte in bytes {
            try Self.appendResponseByte(
                byte,
                to: &data,
                maximumBytes: maximumResponseBytes
            )
        }
        guard isSuccessful else {
            if try NexusToriiDeploymentHealthContract.isRouteUnavailable(
                rejectCode: response.value(
                    forHTTPHeaderField: "x-iroha-reject-code"
                ),
                data: data,
                decoder: decoder
            ) {
                throw NexusToriiError.deploymentUnavailable
            }
            if (try? decodeResponse(NexusJSONValue.self, from: data)) != nil {
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
        expectedHash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusToriiSubmissionResult
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
        expectedHash: String,
        configuration: NexusNetworkConfiguration
    ) async throws -> NexusToriiSubmissionResult {
        try await transport.submit(
            signedNorito: signedNorito,
            idempotencyKey: idempotencyKey,
            expectedHash: expectedHash,
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
    private var transportStarted = false

    /// An in-memory boundary for recovery copy; it never changes journal or wire data.
    var submissionMayHaveStarted: Bool {
        submissionLock.lock()
        defer { submissionLock.unlock() }
        return transportStarted
    }

    func markTransportStarted() {
        submissionLock.lock()
        defer { submissionLock.unlock() }
        transportStarted = true
    }

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

/// Legacy schema field retained so older encoded rows and focused migration
/// fixtures still compile. First-release Taira rows do not populate or admit it.
struct NexusPendingTairaDeploymentIdentity: Codable, Equatable {
    let manifestSha256: String
    let deploymentEpoch: UInt64
    let genesisHash: String

    static func admitted(
        for configuration: NexusNetworkConfiguration,
        deployment: TairaDeploymentBinding? = nil
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
    /// Exact chain UUID used to construct and sign this transaction. Taira
    /// admits only the canonical first-release UUID.
    let chainId: UUID?
    /// Decoding compatibility only; current Taira rows require this to be nil.
    var tairaDeployment: NexusPendingTairaDeploymentIdentity? = nil
    let sender: String
    let receiver: String
    /// Exact opaque definition selected by `xor#universal` when the signed
    /// transaction was prepared. Taira requires this binding on every row.
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

    func hasCurrentDeploymentIdentity(
        for configuration: NexusNetworkConfiguration,
        tairaBinding: TairaDeploymentBinding? = nil
    ) -> Bool {
        guard chainId == configuration.chainId else {
            return false
        }
        switch configuration.networkId {
        case .taira:
            guard configuration.satisfiesCurrentTairaContract else {
                return false
            }
            if let tairaBinding {
                let expected = NexusPendingTairaDeploymentIdentity.admitted(
                    for: configuration,
                    deployment: tairaBinding
                )
                return expected != nil && tairaDeployment == expected
            }
            return tairaDeployment == nil
        case .minamoto:
            return tairaDeployment == nil
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
        let addressDiscriminant: Int
        if transaction.networkId == .taira,
           allowsReadOnlyHistoricalChain {
            guard
                transaction.chainId == TairaDeploymentBinding.canonicalChainId,
                transaction.tairaDeployment == nil,
                transaction.assetDefinitionID ==
                    NexusAssetDefinitionIdentity.tairaXorDefinitionID
            else {
                throw NexusToriiError.invalidResponse
            }
            addressDiscriminant =
                NexusDerivationProfile.taira.i105Discriminant
        } else {
            guard let admittedConfiguration else {
                throw NexusToriiError.invalidResponse
            }
            addressDiscriminant = admittedConfiguration.i105Discriminant
        }
        guard
            !transaction.walletId.isEmpty,
            transaction.walletId.utf8.count <= 512,
            let amount = NexusExactDecimal(transaction.amount.rawValue),
            let fee = NexusExactDecimal(transaction.fee.rawValue),
            amount.unscaled > 0,
            fee.unscaled >= 0,
            amount.scale <= NexusAmountPolicy.maximumScale(
                for: transaction.networkId
            ),
            fee.scale <= NexusAmountPolicy.maximumScale(
                for: transaction.networkId
            ),
            transaction.createdAt.timeIntervalSince1970.isFinite,
            transaction.updatedAt.timeIntervalSince1970.isFinite,
            transaction.updatedAt >= transaction.createdAt,
            transaction.errorClass.map({
                !$0.isEmpty &&
                    $0.utf8.count <= 256 &&
                    $0.rangeOfCharacter(from: .newlines) == nil
            }) ?? true,
            transaction.assetDefinitionID.map({ id in
                if transaction.networkId == .taira {
                    return id == NexusAssetDefinitionIdentity
                        .tairaXorDefinitionID
                }
                return NexusAssetDefinitionIdentity.hasCanonicalWireShape(id)
            }) ?? true,
            transaction.tairaDeployment == nil
        else {
            throw NexusToriiError.invalidResponse
        }
        if !allowsReadOnlyHistoricalChain {
            guard
                let admittedConfiguration,
                transaction.hasCurrentDeploymentIdentity(
                    for: admittedConfiguration
                )
            else {
                throw NexusToriiError.invalidResponse
            }
        }
        _ = try IrohaAddressCodec.parse(
            transaction.sender,
            expectedDiscriminant: addressDiscriminant
        )
        _ = try IrohaAddressCodec.parse(
            transaction.receiver,
            expectedDiscriminant: addressDiscriminant
        )

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
        guard NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
            assetDefinitionID,
            configuration: configuration
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
            amount.unscaled > 0,
            amount.scale <= NexusAmountPolicy.maximumScale(
                for: configuration.networkId
            )
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
        prepared.markTransportStarted()
        do {
            async let submittedResult = submissionClient.submit(
                signedNorito: immutableSignedPayload,
                idempotencyKey: immutableIdempotencyKey,
                expectedHash: expectedHash,
                configuration: configuration
            )
            // The transport task now owns the immutable signed request. Do
            // not stall account switching/deletion while Torii responds.
            transportLease.release()
            let result = try await submittedResult
            let appliedHeight = try result.validate(
                expectedHash: expectedHash,
                configuration: configuration
            )
            pending.state = configuration.networkId == .taira ?
                .committedPendingReconciliation : .submitted
            pending.terminalBlockHeight = appliedHeight
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
            if let classified = error as? NexusToriiError {
                throw classified
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
            NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
                assetDefinitionID,
                configuration: configuration
            ),
            quote.networkId == configuration.networkId,
            quote.authority == request.sender,
            quote.receiver == request.receiver,
            quote.assetDefinitionId == assetDefinitionID,
            quote.amount == request.amount,
            !quote.quoteIdentity.isEmpty,
            quote.validUntilBlock.map({ $0 > 0 }) ?? true,
            let fee = NexusExactDecimal(quote.fee.rawValue),
            fee.unscaled > 0,
            fee.scale <= NexusAmountPolicy.maximumScale(
                for: configuration.networkId
            ),
            NexusAmountPolicy.accepts(
                request.amount,
                networkId: configuration.networkId
            )
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
        guard let configuration = NexusNetworkConfiguration.configuration(
            for: networkId
        ) else {
            return false
        }
        return NexusSendAvailabilityPolicy.permits(
            networkId: networkId,
            nexusEnabled: settings.nexusEnabled,
            sendsEnabled: settings.nexusSendsEnabled,
            tairaEnabled: settings.isTairaEnabled,
            networkAdmitted: configuration.satisfiesCurrentTairaContract,
            signerQualified: signer.isQualified(for: configuration),
            finalityQualified: finalityReader.isQualified(for: configuration)
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
            let configuration = NexusNetworkConfiguration.configuration(
                for: transaction.networkId
            ),
            NexusAssetDefinitionIdentity.isQualifiedXorDefinitionID(
                assetDefinitionID,
                configuration: configuration
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

    private var recoveryTask: Task<Void, Never>?
    private var walletStorageReady = false
    private var restartAfterStorageReady = false

    private init() {
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
