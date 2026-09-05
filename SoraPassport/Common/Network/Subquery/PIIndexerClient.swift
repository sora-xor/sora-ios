// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation

final class PIRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate {
    static let shared = PIRedirectRejectingDelegate()

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

enum PIStrictJSONAdmission {
    static let maximumBytes = 4 * 1024 * 1024
    static let maximumDepth = 64
    static let maximumTokens = 500_000
    static let maximumHealthIntegerBytes = 4_096

    private static let healthIntegerFieldNames: Set<String> = [
        "latestIndexedBlock",
        "latestIndexedAt",
        "workerLatestFinalizedBlock",
        "workerLatestIndexedBlock",
        "workerLag",
        "workerLastSuccessfulIndexTimestamp",
        "workerLastErrorTimestamp",
    ]

    static func validate(_ data: Data) throws {
        try validate(
            data,
            maximumBytes: maximumBytes,
            maximumDepth: maximumDepth,
            maximumTokens: maximumTokens
        )
    }

    static func validate(
        _ data: Data,
        maximumBytes: Int,
        maximumDepth: Int,
        maximumTokens: Int
    ) throws {
        guard
            maximumBytes > 0,
            maximumDepth > 0,
            maximumTokens > 0,
            data.count <= maximumBytes
        else {
            throw PIIndexerError.invalidResponse
        }
        var parser = Parser(
            bytes: Array(data),
            maximumDepth: maximumDepth,
            maximumTokens: maximumTokens
        )
        try parser.parseDocument()
    }

    private struct Parser {
        let bytes: [UInt8]
        let maximumDepth: Int
        let maximumTokens: Int
        var index = 0
        var tokenCount = 0

        mutating func parseDocument() throws {
            skipWhitespace()
            try parseValue(
                depth: 1,
                memberName: nil,
                enforceCanonicalHealthIntegers: false
            )
            skipWhitespace()
            guard index == bytes.count else { try invalid() }
        }

        private mutating func parseValue(
            depth: Int,
            memberName: String?,
            enforceCanonicalHealthIntegers: Bool
        ) throws {
            guard depth <= maximumDepth else { try invalid() }
            try admitToken()
            guard let byte = peek() else { try invalid() }
            let requiresCanonicalHealthInteger =
                enforceCanonicalHealthIntegers && (
                    memberName.map {
                        PIStrictJSONAdmission.healthIntegerFieldNames.contains($0)
                    } ?? false
                )
            switch byte {
            case 0x7B: // {
                guard !requiresCanonicalHealthInteger else {
                    try invalidHealthInteger()
                }
                try parseObject(depth: depth, objectName: memberName)
            case 0x5B: // [
                guard !requiresCanonicalHealthInteger else {
                    try invalidHealthInteger()
                }
                try parseArray(depth: depth)
            case 0x22: // "
                let value = try parseString(
                    capturingValue: requiresCanonicalHealthInteger
                )
                if requiresCanonicalHealthInteger {
                    try requireCanonicalHealthInteger(value)
                }
            case 0x74: // true
                guard !requiresCanonicalHealthInteger else {
                    try invalidHealthInteger()
                }
                try consumeLiteral([0x74, 0x72, 0x75, 0x65])
            case 0x66: // false
                guard !requiresCanonicalHealthInteger else {
                    try invalidHealthInteger()
                }
                try consumeLiteral([0x66, 0x61, 0x6C, 0x73, 0x65])
            case 0x6E: // null
                try consumeLiteral([0x6E, 0x75, 0x6C, 0x6C])
            case 0x2D, 0x30 ... 0x39: // - or digit
                let start = index
                try parseNumber()
                if requiresCanonicalHealthInteger {
                    try requireCanonicalHealthInteger(
                        bytes[start ..< index]
                    )
                }
            default:
                try invalid()
            }
        }

        private mutating func parseObject(
            depth: Int,
            objectName: String?
        ) throws {
            try consume(0x7B)
            skipWhitespace()
            if consumeIfPresent(0x7D) { return }
            var names = Set<String>()
            let membersAreHealthIntegers =
                objectName == "_health" || objectName == "health"
            while true {
                guard peek() == 0x22 else { try invalid() }
                try admitToken()
                let name = try parseString(capturingValue: true)
                guard names.insert(name).inserted else { try invalid() }
                skipWhitespace()
                try consume(0x3A) // :
                skipWhitespace()
                try parseValue(
                    depth: depth + 1,
                    memberName: name,
                    enforceCanonicalHealthIntegers: membersAreHealthIntegers
                )
                skipWhitespace()
                if consumeIfPresent(0x7D) { return }
                try consume(0x2C) // ,
                skipWhitespace()
            }
        }

        private mutating func parseArray(depth: Int) throws {
            try consume(0x5B)
            skipWhitespace()
            if consumeIfPresent(0x5D) { return }
            while true {
                try parseValue(
                    depth: depth + 1,
                    memberName: nil,
                    enforceCanonicalHealthIntegers: false
                )
                skipWhitespace()
                if consumeIfPresent(0x5D) { return }
                try consume(0x2C)
                skipWhitespace()
            }
        }

        private mutating func parseString(capturingValue: Bool) throws -> String {
            try consume(0x22)
            var decoded = ""
            var chunkStart = index
            while index < bytes.count {
                let byte = bytes[index]
                if byte == 0x22 {
                    try appendUTF8Chunk(
                        from: chunkStart,
                        to: index,
                        capturingValue: capturingValue,
                        decoded: &decoded
                    )
                    index += 1
                    return decoded
                }
                if byte == 0x5C { // backslash
                    try appendUTF8Chunk(
                        from: chunkStart,
                        to: index,
                        capturingValue: capturingValue,
                        decoded: &decoded
                    )
                    index += 1
                    guard index < bytes.count else { try invalid() }
                    let escaped = bytes[index]
                    index += 1
                    switch escaped {
                    case 0x22, 0x5C, 0x2F:
                        if capturingValue {
                            guard let scalar = UnicodeScalar(UInt32(escaped)) else {
                                try invalid()
                            }
                            decoded.append(contentsOf: String(scalar))
                        }
                    case 0x62:
                        if capturingValue { decoded.append("\u{08}") }
                    case 0x66:
                        if capturingValue { decoded.append("\u{0C}") }
                    case 0x6E:
                        if capturingValue { decoded.append("\n") }
                    case 0x72:
                        if capturingValue { decoded.append("\r") }
                    case 0x74:
                        if capturingValue { decoded.append("\t") }
                    case 0x75:
                        let scalar = try parseEscapedUnicodeScalar()
                        if capturingValue {
                            decoded.append(contentsOf: String(scalar))
                        }
                    default:
                        try invalid()
                    }
                    chunkStart = index
                    continue
                }
                guard byte >= 0x20 else { try invalid() }
                index += 1
            }
            try invalid()
        }

        private mutating func appendUTF8Chunk(
            from start: Int,
            to end: Int,
            capturingValue: Bool,
            decoded: inout String
        ) throws {
            guard let chunk = String(
                bytes: bytes[start ..< end],
                encoding: .utf8
            ) else {
                try invalid()
            }
            if capturingValue { decoded.append(chunk) }
        }

        private mutating func parseEscapedUnicodeScalar() throws -> UnicodeScalar {
            let first = try consumeHexQuad()
            let scalarValue: UInt32
            if (0xD800 ... 0xDBFF).contains(first) {
                try consume(0x5C)
                try consume(0x75)
                let second = try consumeHexQuad()
                guard (0xDC00 ... 0xDFFF).contains(second) else { try invalid() }
                scalarValue = 0x1_0000 +
                    (UInt32(first - 0xD800) << 10) +
                    UInt32(second - 0xDC00)
            } else {
                guard !(0xDC00 ... 0xDFFF).contains(first) else { try invalid() }
                scalarValue = UInt32(first)
            }
            guard let scalar = UnicodeScalar(scalarValue) else { try invalid() }
            return scalar
        }

        private mutating func consumeHexQuad() throws -> UInt16 {
            var value: UInt16 = 0
            for _ in 0 ..< 4 {
                guard let byte = peek(), let digit = hexDigit(byte) else { try invalid() }
                value = (value << 4) | UInt16(digit)
                index += 1
            }
            return value
        }

        private func hexDigit(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 0x30 ... 0x39: return byte - 0x30
            case 0x41 ... 0x46: return byte - 0x41 + 10
            case 0x61 ... 0x66: return byte - 0x61 + 10
            default: return nil
            }
        }

        private mutating func parseNumber() throws {
            if consumeIfPresent(0x2D), !isDigit(peek()) { try invalid() }
            if consumeIfPresent(0x30) {
                if isDigit(peek()) { try invalid() }
            } else {
                guard let byte = peek(), (0x31 ... 0x39).contains(byte) else {
                    try invalid()
                }
                consumeDigits()
            }
            if consumeIfPresent(0x2E) {
                guard isDigit(peek()) else { try invalid() }
                consumeDigits()
            }
            var hasExponent = consumeIfPresent(0x65)
            if !hasExponent {
                hasExponent = consumeIfPresent(0x45)
            }
            if hasExponent {
                if !consumeIfPresent(0x2B) {
                    _ = consumeIfPresent(0x2D)
                }
                guard isDigit(peek()) else { try invalid() }
                consumeDigits()
            }
        }

        private mutating func consumeDigits() {
            while isDigit(peek()) { index += 1 }
        }

        private func isDigit(_ byte: UInt8?) -> Bool {
            guard let byte else { return false }
            return (0x30 ... 0x39).contains(byte)
        }

        private mutating func consumeLiteral(_ literal: [UInt8]) throws {
            guard index + literal.count <= bytes.count else { try invalid() }
            for expected in literal {
                try consume(expected)
            }
        }

        private mutating func consume(_ expected: UInt8) throws {
            guard peek() == expected else { try invalid() }
            index += 1
        }

        private mutating func consumeIfPresent(_ expected: UInt8) -> Bool {
            guard peek() == expected else { return false }
            index += 1
            return true
        }

        private func requireCanonicalHealthInteger(_ value: String) throws {
            try requireCanonicalHealthInteger(value.utf8)
        }

        private func requireCanonicalHealthInteger<Bytes: Collection>(
            _ value: Bytes
        ) throws where Bytes.Element == UInt8 {
            guard
                !value.isEmpty,
                value.count <= PIStrictJSONAdmission.maximumHealthIntegerBytes,
                let first = value.first,
                first == 0x30 || (0x31 ... 0x39).contains(first),
                (first != 0x30 || value.count == 1),
                value.allSatisfy({ (0x30 ... 0x39).contains($0) })
            else {
                try invalidHealthInteger()
            }
        }

        private mutating func admitToken() throws {
            tokenCount += 1
            guard tokenCount <= maximumTokens else { try invalid() }
        }

        private mutating func skipWhitespace() {
            while let byte = peek(), [0x20, 0x09, 0x0A, 0x0D].contains(byte) {
                index += 1
            }
        }

        private func peek() -> UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        private func invalid() throws -> Never {
            throw PIIndexerError.invalidResponse
        }

        private func invalidHealthInteger() throws -> Never {
            // Never retain the rejected server lexeme in an Error value.
            throw PIIndexerError.invalidQuantity
        }
    }
}

struct PIQuantity: Codable, Equatable, Hashable, CustomStringConvertible, Sendable {
    static let maximumWireBytes = 4_096

    let rawValue: String

    var description: String { rawValue }

    init(_ rawValue: String) throws {
        guard rawValue.utf8.count <= Self.maximumWireBytes else {
            throw PIIndexerError.invalidQuantity
        }
        let decimalPattern = #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$"#
        let decimalMatch = rawValue.range(
            of: decimalPattern,
            options: .regularExpression
        )
        guard decimalMatch == (rawValue.startIndex ..< rawValue.endIndex) else {
            throw PIIndexerError.invalidQuantity
        }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // JSONDecoder exposes numeric literals only after conversion through
        // Foundation Decimal, which cannot preserve every arbitrary-precision
        // wire value. PI's production quantity contract therefore requires
        // decimal strings and fails closed on numeric JSON tokens.
        try self.init(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Floating point conversion is deliberately available only to chart and
    /// presentation adapters. Balances, fees, quotes and transaction inputs
    /// retain `rawValue` through validation and signing.
    var finiteDoubleForRendering: Double? {
        let value = NSDecimalNumber(
            string: rawValue,
            locale: Locale(identifier: "en_US_POSIX")
        ).doubleValue
        return value.isFinite ? value : nil
    }

    var unitIntervalDoubleForRendering: Double? {
        guard
            !rawValue.hasPrefix("-"),
            let value = finiteDoubleForRendering,
            (0 ... 1).contains(value)
        else {
            return nil
        }
        return value
    }

    /// PI's canonical Polkamarkt `probability` field is a percentage in the
    /// closed interval 0...100, while `priceYes` and `priceNo` are unit values.
    /// Convert only at the chart/presentation boundary.
    var percentageFractionForRendering: Double? {
        guard
            !rawValue.hasPrefix("-"),
            let value = finiteDoubleForRendering,
            (0 ... 100).contains(value)
        else {
            return nil
        }
        return value / 100
    }

    /// Bounded Foundation decimal conversion for existing presentation-only
    /// fiat/APY consumers. The authoritative PI value remains `rawValue`;
    /// transaction, balance, fee, and quote paths never use this adapter.
    var decimalValue: Decimal? {
        Decimal(
            string: rawValue,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

enum PIJSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case string(String)
    case number(String)
    case array([PIJSONValue])
    case object([String: PIJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int64.self) {
            // Generic history metadata legitimately contains bounded integer
            // identifiers (for example a Polkamarkt market id). Int64/UInt64
            // decoding is exact; arbitrary-precision quantities remain
            // string-only through PIQuantity.
            self = .number(String(value))
        } else if let value = try? container.decode(UInt64.self) {
            self = .number(String(value))
        } else if let value = try? container.decode([PIJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(
            [String: PIJSONValue].self
        ) {
            self = .object(value)
        } else {
            // JSONDecoder cannot expose a fractional or unbounded numeric
            // token's original lexeme. Those values must be strings so no
            // quantity or metadata value can be rounded through Double or
            // Foundation Decimal.
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "PI generic numeric values must be encoded as strings."
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
                throw PIIndexerError.invalidQuantity
            }
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

struct PIGraphQLError: Decodable, Equatable {
    let message: String
    let path: [PIJSONValue]?
}

enum PIIndexerError: LocalizedError {
    case invalidResponse
    case requestTooLarge
    case responseTooLarge
    case httpStatus(Int)
    case graphQLErrors
    case missingData
    // Keep malformed server/user wire text out of Error reflection and generic
    // logging. Callers only need the privacy-safe protocol class.
    case invalidQuantity
    case invalidServiceIdentity
    case invalidChainIdentity
    case missingChainIdentityCapability
    case staleCheckpoint
    case invalidPageSize
    case paginationLimit
    // PI cursors are opaque and may encode account-bound query state. Do not
    // retain them in an Error that generic infrastructure can reflect or log.
    case repeatedCursor
    case repeatedPage
    case typedAccountBalancesUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "PI returned an invalid response."
        case .requestTooLarge:
            return "The PI request exceeded the bounded mobile request limit."
        case .responseTooLarge:
            return "PI returned more data than the mobile response limit."
        case let .httpStatus(code):
            return "PI returned HTTP \(code)."
        case .graphQLErrors:
            // GraphQL messages can echo filters or account identifiers. Keep
            // them available only for in-memory protocol diagnosis and never
            // surface or log the raw server text.
            return "PI rejected the requested operation."
        case .missingData:
            return "PI returned no data."
        case .invalidQuantity:
            return "PI returned an invalid precise quantity."
        case .invalidServiceIdentity:
            return "PI service identity did not match the reviewed production service."
        case .invalidChainIdentity:
            return "PI is not indexed from SORA mainnet."
        case .missingChainIdentityCapability:
            return "PI does not expose the reviewed SORA2 genesis and finalized checkpoint identity required by this release."
        case .staleCheckpoint:
            return "PI has no finalized indexing checkpoint."
        case .invalidPageSize:
            return "The requested PI page size is outside the mobile limit."
        case .paginationLimit:
            return "PI pagination exceeded the bounded mobile limit."
        case .repeatedCursor:
            return "PI repeated a pagination cursor."
        case .repeatedPage:
            return "PI repeated a page without making pagination progress."
        case .typedAccountBalancesUnavailable:
            return "PI schema v1 does not expose a reviewed typed account-balance contract."
        }
    }

    var allowsOfflineFallback: Bool {
        guard case let .httpStatus(code) = self else {
            return false
        }
        return code == 408 || code == 429 || (500 ... 599).contains(code)
    }
}

struct PIPageInfo: Decodable, Equatable {
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    let startCursor: String?
    let endCursor: String?
}

private struct PICanonicalHealthInteger: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer
        do {
            container = try decoder.singleValueContainer()
        } catch {
            throw PIIndexerError.invalidQuantity
        }

        if let rawValue = try? container.decode(String.self) {
            guard
                rawValue.utf8.count <=
                    PIStrictJSONAdmission.maximumHealthIntegerBytes,
                !rawValue.isEmpty,
                rawValue.utf8.allSatisfy({ (0x30 ... 0x39).contains($0) }),
                rawValue == "0" || rawValue.first != "0",
                let exactValue = Int(rawValue),
                exactValue >= 0
            else {
                throw PIIndexerError.invalidQuantity
            }
            value = exactValue
            return
        }

        // PIStrictJSONAdmission validates the original numeric token before
        // Foundation can normalize an exponent or fractional spelling. These
        // bounded conversions only project that already-canonical unsigned
        // lexeme into the health domain's Int representation.
        if let signedValue = try? container.decode(Int.self) {
            guard signedValue >= 0 else {
                throw PIIndexerError.invalidQuantity
            }
            value = signedValue
            return
        }
        if
            let unsignedValue = try? container.decode(UInt64.self),
            let exactValue = Int(exactly: unsignedValue)
        {
            value = exactValue
            return
        }
        throw PIIndexerError.invalidQuantity
    }
}

struct PIHealth: Equatable {
    let ok: Bool
    let repositoryReady: Bool
    let service: String
    let serviceId: String
    let schemaVersion: Int
    let ecosystem: String
    let chainId: String
    let network: String
    let publicBaseUrl: URL?
    let readOnly: Bool
    let genesisHash: String?
    let latestIndexedBlock: Int?
    let latestIndexedBlockHash: String?
    let latestIndexedAt: Int?
    let workerAvailable: Bool
    let workerReady: Bool?
    let workerReadinessReason: String?
    let workerLifecycle: String?
    let workerStartupComplete: Bool?
    let workerLatestFinalizedBlock: Int?
    let workerLatestIndexedBlock: Int?
    let workerLag: Int?
    let workerLastSuccessfulIndexTimestamp: Int?
    let workerLastError: String?
    let workerLastErrorTimestamp: Int?

    var finalizedCheckpoint: Int? {
        latestIndexedBlock ?? workerLatestIndexedBlock
    }
}

extension PIHealth: Codable {
    private enum CodingKeys: String, CodingKey {
        case ok
        case repositoryReady
        case service
        case serviceId
        case schemaVersion
        case ecosystem
        case chainId
        case network
        case publicBaseUrl
        case readOnly
        case genesisHash
        case latestIndexedBlock
        case latestIndexedBlockHash
        case latestIndexedAt
        case workerAvailable
        case workerReady
        case workerReadinessReason
        case workerLifecycle
        case workerStartupComplete
        case workerLatestFinalizedBlock
        case workerLatestIndexedBlock
        case workerLag
        case workerLastSuccessfulIndexTimestamp
        case workerLastError
        case workerLastErrorTimestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decode(Bool.self, forKey: .ok)
        repositoryReady = try container.decode(
            Bool.self,
            forKey: .repositoryReady
        )
        service = try container.decode(String.self, forKey: .service)
        serviceId = try container.decode(String.self, forKey: .serviceId)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        ecosystem = try container.decode(String.self, forKey: .ecosystem)
        chainId = try container.decode(String.self, forKey: .chainId)
        network = try container.decode(String.self, forKey: .network)
        publicBaseUrl = try container.decodeIfPresent(
            URL.self,
            forKey: .publicBaseUrl
        )
        readOnly = try container.decode(Bool.self, forKey: .readOnly)
        genesisHash = try container.decodeIfPresent(
            String.self,
            forKey: .genesisHash
        )
        latestIndexedBlock = try Self.decodeInteger(
            from: container,
            forKey: .latestIndexedBlock
        )
        latestIndexedBlockHash = try container.decodeIfPresent(
            String.self,
            forKey: .latestIndexedBlockHash
        )
        latestIndexedAt = try Self.decodeInteger(
            from: container,
            forKey: .latestIndexedAt
        )
        workerAvailable = try container.decode(
            Bool.self,
            forKey: .workerAvailable
        )
        workerReady = try container.decodeIfPresent(
            Bool.self,
            forKey: .workerReady
        )
        workerReadinessReason = try container.decodeIfPresent(
            String.self,
            forKey: .workerReadinessReason
        )
        workerLifecycle = try container.decodeIfPresent(
            String.self,
            forKey: .workerLifecycle
        )
        workerStartupComplete = try container.decodeIfPresent(
            Bool.self,
            forKey: .workerStartupComplete
        )
        workerLatestFinalizedBlock = try Self.decodeInteger(
            from: container,
            forKey: .workerLatestFinalizedBlock
        )
        workerLatestIndexedBlock = try Self.decodeInteger(
            from: container,
            forKey: .workerLatestIndexedBlock
        )
        workerLag = try Self.decodeInteger(
            from: container,
            forKey: .workerLag
        )
        workerLastSuccessfulIndexTimestamp = try Self.decodeInteger(
            from: container,
            forKey: .workerLastSuccessfulIndexTimestamp
        )
        workerLastError = try container.decodeIfPresent(
            String.self,
            forKey: .workerLastError
        )
        workerLastErrorTimestamp = try Self.decodeInteger(
            from: container,
            forKey: .workerLastErrorTimestamp
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ok, forKey: .ok)
        try container.encode(repositoryReady, forKey: .repositoryReady)
        try container.encode(service, forKey: .service)
        try container.encode(serviceId, forKey: .serviceId)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(ecosystem, forKey: .ecosystem)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(network, forKey: .network)
        try container.encodeIfPresent(publicBaseUrl, forKey: .publicBaseUrl)
        try container.encode(readOnly, forKey: .readOnly)
        try container.encodeIfPresent(genesisHash, forKey: .genesisHash)
        try container.encodeIfPresent(
            latestIndexedBlock,
            forKey: .latestIndexedBlock
        )
        try container.encodeIfPresent(
            latestIndexedBlockHash,
            forKey: .latestIndexedBlockHash
        )
        try container.encodeIfPresent(latestIndexedAt, forKey: .latestIndexedAt)
        try container.encode(workerAvailable, forKey: .workerAvailable)
        try container.encodeIfPresent(workerReady, forKey: .workerReady)
        try container.encodeIfPresent(
            workerReadinessReason,
            forKey: .workerReadinessReason
        )
        try container.encodeIfPresent(
            workerLifecycle,
            forKey: .workerLifecycle
        )
        try container.encodeIfPresent(
            workerStartupComplete,
            forKey: .workerStartupComplete
        )
        try container.encodeIfPresent(
            workerLatestFinalizedBlock,
            forKey: .workerLatestFinalizedBlock
        )
        try container.encodeIfPresent(
            workerLatestIndexedBlock,
            forKey: .workerLatestIndexedBlock
        )
        try container.encodeIfPresent(workerLag, forKey: .workerLag)
        try container.encodeIfPresent(
            workerLastSuccessfulIndexTimestamp,
            forKey: .workerLastSuccessfulIndexTimestamp
        )
        try container.encodeIfPresent(
            workerLastError,
            forKey: .workerLastError
        )
        try container.encodeIfPresent(
            workerLastErrorTimestamp,
            forKey: .workerLastErrorTimestamp
        )
    }

    private static func decodeInteger(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Int? {
        try container.decodeIfPresent(
            PICanonicalHealthInteger.self,
            forKey: key
        )?.value
    }
}

struct PIReadQualification: Equatable {
    enum Source: Equatable {
        case live
        case cache
    }

    let health: PIHealth
    let source: Source
}

struct PIQualifiedRead<Value> {
    let value: Value
    let qualification: PIReadQualification?
}

struct PIMobileChainNode: Decodable, Equatable {
    let name: String
    let address: URL
}

struct PIMobileConfig: Decodable, Equatable {
    let blockExplorerUrl: URL
    let substrateTypesUrl: URL?
    let soracard: Bool
    let nodes: [PIMobileChainNode]
    let nexusAvailable: Bool
    let nexusSendsAvailable: Bool
    let polkamarktVisible: Bool
    let polkamarktMutationsAvailable: Bool
    let tairaDefaultVisible: Bool

    /// PI schema v1 exposes only `account(id): JSON`. Balances remain unavailable until PI
    /// publishes a typed, account/asset/checkpoint-bound wire contract; runtime RPC stays
    /// authoritative meanwhile.
    var typedAccountBalancesAvailable: Bool { false }
}

struct PIAsset: Decodable, Equatable {
    let id: String
    let priceUSD: PIQuantity?
    let supply: PIQuantity?
    let liquidity: PIQuantity?
    let liquidityBooks: PIQuantity?
    let priceChangeDay: Double?
    let priceChangeWeek: Double?
    let volumeDayUSD: PIQuantity?
    let volumeWeekUSD: PIQuantity?
}

struct PIPoolXYK: Decodable, Equatable, Identifiable {
    let id: String
    let baseAssetId: String?
    let targetAssetId: String?
    let baseAssetReserves: PIQuantity?
    let targetAssetReserves: PIQuantity?
    let priceUSD: PIQuantity?
    let strategicBonusApy: PIQuantity?
    let poolTokenSupply: PIQuantity?
    let poolTokenPriceUSD: PIQuantity?
    let liquidityUSD: PIQuantity?
}

struct PIReferrerReward: Decodable, Equatable, Identifiable {
    let id: String
    let referral: String?
    let referrer: String?
    let blockHeight: String?
    let timestamp: Int?
    let amount: PIQuantity?
}

struct PIHistoryElement: Codable, Equatable {
    struct CallConnection: Codable, Equatable {
        struct Call: Codable, Equatable {
            let module: String?
            let method: String?
            let data: PIJSONValue?
        }

        let nodes: [Call]
    }

    let id: String
    let type: String?
    let timestamp: Int?
    let blockHash: String?
    let blockHeight: Int?
    let module: String?
    let method: String?
    let address: String?
    let networkFee: PIQuantity?
    let execution: PIJSONValue?
    let data: PIJSONValue?
    let dataFrom: String?
    let dataTo: String?
    let dataAssets: [String]?
    let callNames: [String]?
    let calls: CallConnection?
}

struct PIMarket: Decodable, Equatable, Identifiable {
    let id: String
    let marketId: Int?
    let conditionId: Int?
    let title: String?
    let category: String?
    let tags: String?
    let description: String?
    let metadataUri: URL?
    let rulesUri: URL?
    let resolutionSource: String?
    let closeBlock: Int?
    let status: String?
    let mechanism: String?
    let creator: String?
    let collateralAsset: String?
    let creatorFees: PIQuantity?
    let liquidityUSD: PIQuantity?
    let volumeUSD: PIQuantity?
    let probability: PIQuantity?
    let priceYes: PIQuantity?
    let priceNo: PIQuantity?
    let virtualDepth: PIQuantity?
    let dpmCollateral: PIQuantity?
    let realYesShares: PIQuantity?
    let realNoShares: PIQuantity?
    let marginalYesPriceBps: Int?
    let marginalNoPriceBps: Int?
    let collateral: PIQuantity?
    let yesShares: PIQuantity?
    let noShares: PIQuantity?
    let resolutionOutcome: String?
    let resolutionEvidenceUri: URL?
    let cancellationEvidenceUri: URL?
    let governanceUrl: URL?
    let updatedAtBlock: Int?
    let timestamp: Int?
}

struct PIMarketSnapshot: Decodable, Equatable, Identifiable {
    let id: String
    let marketId: Int?
    let timestamp: Int?
    let blockHeight: Int?
    let type: String?
    let probability: PIQuantity?
    let priceYes: PIQuantity?
    let priceNo: PIQuantity?
    let virtualDepth: PIQuantity?
    let dpmCollateral: PIQuantity?
    let realYesShares: PIQuantity?
    let realNoShares: PIQuantity?
    let collateral: PIQuantity?
    let yesShares: PIQuantity?
    let noShares: PIQuantity?
    let liquidityUSD: PIQuantity?
    let volumeUSD: PIQuantity?
    let status: String?
}

struct PIAccountPosition: Decodable, Equatable, Identifiable {
    let id: String
    let account: String?
    let marketId: Int?
    let outcome: String?
    let shares: PIQuantity?
    let yesShares: PIQuantity?
    let noShares: PIQuantity?
    let netCollateralPaid: PIQuantity?
    let costBasisUsd: PIQuantity?
    let marketValueUsd: PIQuantity?
    let realizedPnlUsd: PIQuantity?
    let unrealizedPnlUsd: PIQuantity?
    let claimablePayoutUsd: PIQuantity?
    let isCreator: Bool?
    let status: String?
    let updatedAt: String?
    let market: PIMarket?
}

struct PIAccountTrade: Decodable, Equatable, Identifiable {
    let id: String
    let account: String?
    let marketId: Int?
    let marketIds: [Int]?
    let side: String?
    let outcome: String?
    let collateralUsd: PIQuantity?
    let shares: PIQuantity?
    let sharesIn: PIQuantity?
    let sharesOut: PIQuantity?
    let executionPrice: PIQuantity?
    let feeUsd: PIQuantity?
    let realizedPnlUsd: PIQuantity?
    let timestamp: String?
    let blockNumber: Int?
    let blockHash: String?
    let extrinsicHash: String?
    let market: PIMarket?

    func includesMarket(_ marketId: UInt32) -> Bool {
        let wireMarketId = Int(marketId)
        return marketIds?.contains(wireMarketId) == true ||
            self.marketId == wireMarketId
    }
}

struct PIPolkamarktSignals: Decodable, Equatable {
    struct Point: Decodable, Equatable {
        let label: String
        let value: PIQuantity
    }

    struct Answer: Decodable, Equatable {
        let answer: String
        let volumeUsd: PIQuantity
        let markets: Int
    }

    struct AccuracySummary: Decodable, Equatable {
        let accuracyPercent: Double
    }

    let totalVolumeUsd: PIQuantity
    let activeMarkets: Int
    let activeAccounts: Int
    let liquidityUsd: PIQuantity
    let liquiditySeries: [Point]
    let answerBreakdown: [Answer]
    let accuracySummary: AccuracySummary?
}

struct PIConnection<Node: Decodable & Equatable>: Decodable, Equatable {
    struct Edge: Decodable, Equatable {
        let cursor: String?
        let node: Node
    }

    let nodes: [Node]?
    let edges: [Edge]?
    let pageInfo: PIPageInfo
    let totalCount: Int

    var values: [Node] {
        nodes ?? edges?.map(\.node) ?? []
    }
}

private struct PIGraphQLResponse<DataType: Decodable>: Decodable {
    let data: DataType?
    let errors: [PIGraphQLError]?
}

enum PIResponseCacheAdmission {
    static let maximumPayloadBytes = PIStrictJSONAdmission.maximumBytes
    static let maximumEnvelopeBytes = 8 * 1_024 * 1_024

    static func validatePayload(_ data: Data) throws {
        try PIStrictJSONAdmission.validate(data)
    }

    static func validateEnvelope(_ data: Data) throws {
        try PIStrictJSONAdmission.validate(
            data,
            maximumBytes: maximumEnvelopeBytes,
            maximumDepth: 8,
            maximumTokens: 256
        )
    }
}

private actor PIResponseCache {
    private static let maximumEntryBytes =
        PIResponseCacheAdmission.maximumEnvelopeBytes
    private static let maximumTotalBytes = 64 * 1_024 * 1_024
    private static let maximumEntries = 128

    struct Entry: Codable {
        let savedAt: Date
        let payload: Data
        let health: PIHealth?
    }

    private let fileManager: FileManager
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = (try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        directory = base.appendingPathComponent("PIIndexer", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(_ data: Data, health: PIHealth?, key: String) {
        let destination = url(for: key)
        guard
            isUsableDirectory(),
            isSafeDestination(destination),
            data.count <= PIResponseCacheAdmission.maximumPayloadBytes,
            (try? PIResponseCacheAdmission.validatePayload(data)) != nil,
            let encoded = try? encoder.encode(
                Entry(savedAt: Date(), payload: data, health: health)
            ),
            encoded.count <= Self.maximumEntryBytes,
            (try? PIResponseCacheAdmission.validateEnvelope(encoded)) != nil
        else {
            return
        }
        do {
            try encoded.write(
                to: destination,
                options: [
                    .atomic,
                    .completeFileProtectionUntilFirstUserAuthentication,
                ]
            )
            prune()
        } catch {
            // A cache write must never change the qualified live response.
        }
    }

    func load(key: String, maximumAge: TimeInterval) -> Entry? {
        let fileURL = url(for: key)
        guard
            maximumAge >= 0,
            isUsableDirectory(),
            let values = try? fileURL.resourceValues(forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]),
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let fileSize = values.fileSize
        else {
            return nil
        }
        guard fileSize >= 0, fileSize <= Self.maximumEntryBytes else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        // File protection can make an otherwise valid cache temporarily
        // unreadable while the device is locked. Preserve it in that case.
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        guard
            data.count <= Self.maximumEntryBytes,
            (try? PIResponseCacheAdmission.validateEnvelope(data)) != nil,
            let entry = try? decoder.decode(Entry.self, from: data),
            entry.payload.count <=
                PIResponseCacheAdmission.maximumPayloadBytes,
            (try? PIResponseCacheAdmission.validatePayload(entry.payload)) != nil
        else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        let age = Date().timeIntervalSince(entry.savedAt)
        guard age >= 0, age <= maximumAge else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        return entry
    }

    func remove(key: String) {
        try? fileManager.removeItem(at: url(for: key))
    }

    private func url(for key: String) -> URL {
        let safeKey = key.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "_"
        }
        return directory.appendingPathComponent(String(String(safeKey).prefix(180)) + ".json")
    }

    private func isUsableDirectory() -> Bool {
        guard
            let values = try? directory.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
        else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func isSafeDestination(_ destination: URL) -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        ) else {
            return false
        }
        guard let existing = entries.first(where: {
            $0.lastPathComponent == destination.lastPathComponent
        }) else {
            return true
        }
        guard let values = try? existing.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func prune() {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        let files = ((try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []).compactMap { url -> (URL, Int, Date)? in
            guard
                let values = try? url.resourceValues(forKeys: keys),
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let size = values.fileSize,
                size >= 0
            else {
                return nil
            }
            return (
                url,
                size,
                values.contentModificationDate ?? .distantPast
            )
        }.sorted { $0.2 < $1.2 }

        var remainingCount = files.count
        var remainingBytes = files.reduce(0) { partial, file in
            let (sum, overflow) = partial.addingReportingOverflow(file.1)
            return overflow ? Int.max : sum
        }
        for file in files where
            remainingCount > Self.maximumEntries ||
            remainingBytes > Self.maximumTotalBytes
        {
            do {
                try fileManager.removeItem(at: file.0)
                remainingCount -= 1
                remainingBytes =
                    remainingBytes == Int.max
                    ? Int.max
                    : max(0, remainingBytes - file.1)
            } catch {
                // Keep accounting unchanged when removal failed.
            }
        }
    }
}

final class PIIndexerClient {
    static let endpoint = URL(string: "https://pi.soramitsu.io/graphql")!
    static let soraMainnetGenesis =
        "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"

    private let endpoint: URL
    private let session: URLSession
    private let cache = PIResponseCache()
    private let decoder: JSONDecoder
    private static let maximumRequestBytes = 256 * 1024
    static let maximumResponseBytes = 4 * 1024 * 1024
    static let maximumCursorBytes = 4_096
    static let maximumHistoryPages = 20
    private let maximumPageSize = 100

    init(endpoint: URL = PIIndexerClient.endpoint, session: URLSession? = nil) {
        self.endpoint = endpoint
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = true
            configuration.httpMaximumConnectionsPerHost = 4
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(
                configuration: configuration,
                delegate: PIRedirectRejectingDelegate.shared,
                delegateQueue: nil
            )
        }
        decoder = JSONDecoder()
    }

    static func validateProductionEndpoint(_ candidate: URL) throws {
        guard
            candidate == endpoint,
            candidate.absoluteString == endpoint.absoluteString
        else {
            throw PIIndexerError.invalidServiceIdentity
        }
    }

    static func validateRequestBody(_ body: Data) throws {
        guard body.count <= maximumRequestBytes else {
            throw PIIndexerError.requestTooLarge
        }
    }

    static func validateExpectedResponseLength(_ length: Int64) throws {
        guard
            length < 0 || length <= Int64(maximumResponseBytes)
        else {
            throw PIIndexerError.responseTooLarge
        }
    }

    static func validateCursor(_ cursor: String?) throws {
        guard Self.isBoundedCursor(cursor) else {
            throw PIIndexerError.invalidResponse
        }
    }

    static func validateHistoryPagination(after: String?) throws {
        try validateCursor(after)
    }

    static func validateHistoryPage(
        _ page: Int,
        maximumPages: Int = maximumHistoryPages
    ) throws {
        guard
            (1 ... 100).contains(maximumPages),
            (1 ... maximumPages).contains(page)
        else {
            throw PIIndexerError.paginationLimit
        }
    }

    func health(requireLive: Bool = false) async throws -> PIHealth {
        struct Payload: Decodable { let _health: PIHealth }
        let result: Payload = try await execute(
            operationName: "MobileHealth",
            query: """
            query MobileHealth {
              _health {
                ok repositoryReady service serviceId schemaVersion ecosystem
                chainId network publicBaseUrl readOnly
                workerAvailable
                workerReady workerLatestFinalizedBlock workerLatestIndexedBlock workerLag
                workerReadinessReason workerLifecycle workerStartupComplete
                workerLastSuccessfulIndexTimestamp workerLastError workerLastErrorTimestamp
              }
            }
            """,
            cachePolicy: requireLive
                ? .none
                : .offline(maximumAge: TimeInterval(24 * 60 * 60)),
            validateResponse: { payload, _ in
                try Self.validateHealth(payload._health)
            }
        )
        return result._health
    }

    static func validateHealth(
        _ health: PIHealth,
        nowEpochSeconds: Int = Int(Date().timeIntervalSince1970)
    ) throws {
        guard
            health.ok,
            health.repositoryReady,
            health.service == "polkaswap-indexer",
            health.serviceId == "pi.soramitsu.io",
            health.schemaVersion == 1,
            health.readOnly,
            health.ecosystem == "sora2",
            health.chainId == "sora:mainnet",
            health.network == "mainnet",
            health.publicBaseUrl == endpoint,
            health.publicBaseUrl?.absoluteString == endpoint.absoluteString,
            health.workerAvailable,
            health.workerReady == true,
            health.workerReadinessReason == nil,
            health.workerLifecycle == "running",
            health.workerStartupComplete == true
        else {
            throw PIIndexerError.invalidServiceIdentity
        }
        // PI schema v1 exposes a coherent worker finalized/indexed checkpoint,
        // but not the older top-level genesis/hash aliases. The reviewed
        // endpoint/service/chain tuple above binds reads to SORA mainnet; the
        // live worker checkpoint below binds every read to fresh finality.
        if let genesisHash = health.genesisHash,
           genesisHash.caseInsensitiveCompare(Self.soraMainnetGenesis) !=
           .orderedSame {
            throw PIIndexerError.invalidChainIdentity
        }
        if let indexedHash = health.latestIndexedBlockHash,
           indexedHash.range(
               of: #"^0x[0-9a-fA-F]{64}$"#,
               options: .regularExpression
           ) == nil ||
           indexedHash ==
           "0x0000000000000000000000000000000000000000000000000000000000000000" {
            throw PIIndexerError.invalidChainIdentity
        }
        guard
            let workerIndexed = health.workerLatestIndexedBlock,
            let finalized = health.workerLatestFinalizedBlock,
            let lag = health.workerLag,
            let lastSuccessful = health.workerLastSuccessfulIndexTimestamp
        else {
            throw PIIndexerError.staleCheckpoint
        }
        let indexed = health.latestIndexedBlock ?? workerIndexed
        let indexedAt = health.latestIndexedAt ?? lastSuccessful
        let (calculatedLag, lagOverflow) =
            finalized.subtractingReportingOverflow(workerIndexed)
        let (earliestIndexedAt, lowerBoundOverflow) =
            nowEpochSeconds.subtractingReportingOverflow(5 * 60)
        let (latestIndexedAt, upperBoundOverflow) =
            nowEpochSeconds.addingReportingOverflow(30)
        guard
            !lagOverflow,
            !lowerBoundOverflow,
            !upperBoundOverflow,
            lastSuccessful >= earliestIndexedAt,
            lastSuccessful <= latestIndexedAt,
            indexedAt >= earliestIndexedAt,
            indexedAt <= latestIndexedAt,
            indexed > 0,
            finalized > 0,
            indexed == workerIndexed,
            finalized >= workerIndexed,
            lag >= 0,
            calculatedLag == lag,
            lastSuccessful > 0,
            (health.workerLastError == nil) ==
                (health.workerLastErrorTimestamp == nil),
            (health.workerLastError?.count ?? 0) <= 1_000
        else {
            throw PIIndexerError.staleCheckpoint
        }
    }

    static func validateStableResponseCheckpoint(
        preflight: PIHealth,
        postflight: PIHealth
    ) throws {
        let indexedHashMatches: Bool
        switch (
            preflight.latestIndexedBlockHash,
            postflight.latestIndexedBlockHash
        ) {
        case (nil, nil):
            indexedHashMatches = true
        case let (.some(before), .some(after)):
            indexedHashMatches =
                before.caseInsensitiveCompare(after) == .orderedSame
        default:
            indexedHashMatches = false
        }
        guard
            preflight.workerLatestIndexedBlock ==
                postflight.workerLatestIndexedBlock,
            preflight.latestIndexedBlock == postflight.latestIndexedBlock,
            indexedHashMatches,
            preflight.workerLastSuccessfulIndexTimestamp ==
                postflight.workerLastSuccessfulIndexTimestamp,
            preflight.latestIndexedAt == postflight.latestIndexedAt
        else {
            throw PIIndexerError.staleCheckpoint
        }
    }

    static func validateResponseHeights(
        _ heights: [Int?],
        qualification: PIReadQualification?
    ) throws {
        guard
            let checkpoint = qualification?.health.finalizedCheckpoint,
            checkpoint > 0,
            heights.allSatisfy({ height in
                height.map { $0 >= 0 && $0 <= checkpoint } ?? true
            })
        else {
            throw PIIndexerError.staleCheckpoint
        }
    }

    static func validateConnectionPage<Node: Decodable & Equatable>(
        _ page: PIConnection<Node>,
        requestedSize: Int,
        hasPriorPage: Bool,
        itemIdentity: (Node) -> String
    ) throws {
        let values = page.values
        let identities = values.map(itemIdentity)
        guard
            (1 ... 100).contains(requestedSize),
            page.totalCount >= 0,
            values.count <= requestedSize,
            values.count <= page.totalCount,
            (page.nodes != nil) != (page.edges != nil),
            page.pageInfo.hasPreviousPage == hasPriorPage,
            !page.pageInfo.hasNextPage || !values.isEmpty,
            !page.pageInfo.hasNextPage ||
                !(page.pageInfo.endCursor?.isEmpty ?? true),
            Self.isBoundedCursor(page.pageInfo.startCursor),
            Self.isBoundedCursor(page.pageInfo.endCursor),
            hasPriorPage || page.pageInfo.hasNextPage ||
                values.count == page.totalCount,
            identities.allSatisfy({
                !$0.isEmpty &&
                    $0 == $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) &&
                    $0.utf8.count <= 4_096
            }),
            Set(identities).count == identities.count
        else {
            throw PIIndexerError.invalidResponse
        }
    }

    static func validateMarketSnapshots(
        _ values: [PIMarketSnapshot],
        marketId: Int
    ) throws {
        guard
            isRuntimeUInt32(marketId),
            Set(values.map(\.id)).count == values.count,
            isCanonicalAscendingSnapshotOrder(values),
            values.allSatisfy({
                isBoundedIdentifier($0.id) &&
                    $0.marketId == marketId &&
                    // PI persists the canonical five-minute Polkamarkt chart
                    // series as DEFAULT snapshots. BLOCK snapshots are only a
                    // network checkpoint construct and do not exist for
                    // markets.
                    $0.type == "DEFAULT" &&
                    $0.blockHeight != nil &&
                    ($0.blockHeight ?? -1) >= 0 &&
                    $0.timestamp != nil &&
                    ($0.timestamp ?? -1) >= 0 &&
                    isBoundedOptionalLabel($0.status) &&
                    isPercentage($0.probability) &&
                    isUnitInterval($0.priceYes) &&
                    isUnitInterval($0.priceNo) &&
                    [
                        $0.virtualDepth,
                        $0.dpmCollateral,
                        $0.realYesShares,
                        $0.realNoShares,
                        $0.collateral,
                        $0.yesShares,
                        $0.noShares,
                        $0.liquidityUSD,
                        $0.volumeUSD,
                    ].allSatisfy({ isNonNegative($0) })
            })
        else {
            throw PIIndexerError.invalidChainIdentity
        }
    }

    private static func isCanonicalAscendingSnapshotOrder(
        _ values: [PIMarketSnapshot]
    ) -> Bool {
        zip(values, values.dropFirst()).allSatisfy { pair in
            let (left, right) = pair
            guard
                let leftTimestamp = left.timestamp,
                let rightTimestamp = right.timestamp
            else {
                return false
            }
            return leftTimestamp < rightTimestamp ||
                (leftTimestamp == rightTimestamp && left.id < right.id)
        }
    }

    static func validateMarkets(
        _ values: [PIMarket],
        expectedStatus: PolkamarktMarketStatus? = nil
    ) throws {
        guard values.allSatisfy({ market in
            isBoundedIdentifier(market.id) &&
                (market.marketId.map(isRuntimeUInt32) ?? false) &&
                (market.conditionId.map(isRuntimeUInt32) ?? true) &&
                (market.closeBlock.map(isRuntimeUInt32) ?? true) &&
                (market.updatedAtBlock.map({ $0 >= 0 }) ?? false) &&
                (market.timestamp.map({ $0 >= 0 }) ?? true) &&
                isBoundedRequiredLabel(market.status) &&
                (expectedStatus.map({ market.status == $0.rawValue }) ?? true) &&
                isPercentage(market.probability) &&
                isUnitInterval(market.priceYes) &&
                isUnitInterval(market.priceNo) &&
                [
                    market.creatorFees,
                    market.liquidityUSD,
                    market.volumeUSD,
                    market.virtualDepth,
                    market.dpmCollateral,
                    market.realYesShares,
                    market.realNoShares,
                    market.collateral,
                    market.yesShares,
                    market.noShares,
                ].allSatisfy({ isNonNegative($0) }) &&
                isBasisPoints(market.marginalYesPriceBps) &&
                isBasisPoints(market.marginalNoPriceBps)
        }) else {
            throw PIIndexerError.invalidResponse
        }
    }

    static func validateUniqueRuntimeMarketIds(
        _ values: [PIMarket]
    ) throws {
        let marketIds = values.compactMap(\.marketId)
        guard
            marketIds.count == values.count,
            Set(marketIds).count == marketIds.count
        else {
            throw PIIndexerError.invalidChainIdentity
        }
    }

    static func validateAccountHistory(
        _ values: [PIHistoryElement],
        account: String,
        expectedTransactionHashes: Set<String>? = nil
    ) throws {
        let identifiers = values.compactMap {
            PIHistoryCheckpointValidator.canonicalHistoryIdentifier($0.id)
        }
        let canonicalHashes = values.compactMap {
            PIHistoryCheckpointValidator.normalizedTransactionHash($0.id)
        }
        let matchesExpectedHashes = expectedTransactionHashes.map {
            canonicalHashes.count == values.count &&
                Set(canonicalHashes).count == canonicalHashes.count &&
                Set(canonicalHashes).isSubset(of: $0)
        } ?? true
        guard
            !account.isEmpty,
            account == account.trimmingCharacters(in: .whitespacesAndNewlines),
            account.utf8.count <= 512,
            identifiers.count == values.count,
            Set(identifiers).count == identifiers.count,
            values.allSatisfy({
                (
                    $0.address == account ||
                        $0.dataFrom == account ||
                        $0.dataTo == account
                ) &&
                    ($0.timestamp ?? -1) >= 0 &&
                    $0.blockHeight != nil &&
                    ($0.blockHeight ?? -1) >= 0 &&
                    $0.blockHash.flatMap(
                        PIHistoryCheckpointValidator.normalizedBlockHash
                    ) != nil &&
                    PIHistoryCheckpointValidator.executionSucceeded(
                        $0.execution
                    ) != nil &&
                    PIHistoryCheckpointValidator.isNonNegativeIntegerQuantity(
                        $0.networkFee
                    )
            }),
            matchesExpectedHashes
        else {
            throw PIIndexerError.invalidChainIdentity
        }
    }

    static func validateAccountPositions(
        _ values: [PIAccountPosition],
        account: String
    ) throws {
        guard
            isBoundedIdentifier(account),
            Set(values.map(\.id)).count == values.count,
            values.allSatisfy({
                isBoundedIdentifier($0.id) &&
                    $0.account == account &&
                    ($0.marketId.map(isRuntimeUInt32) ?? false) &&
                    $0.market != nil &&
                    $0.market?.marketId == $0.marketId &&
                    [
                        $0.shares,
                        $0.yesShares,
                        $0.noShares,
                        $0.netCollateralPaid,
                        $0.costBasisUsd,
                        $0.marketValueUsd,
                        $0.claimablePayoutUsd,
                    ].allSatisfy({ isNonNegative($0) }) &&
                    isBoundedOptionalLabel($0.outcome) &&
                    isBoundedOptionalLabel($0.status) &&
                    isBoundedOptionalLabel($0.updatedAt)
            })
        else {
            throw PIIndexerError.invalidChainIdentity
        }
        try validateMarkets(values.compactMap(\.market))
    }

    static func validateAccountTrades(
        _ values: [PIAccountTrade],
        account: String
    ) throws {
        guard
            isBoundedIdentifier(account),
            Set(values.map(\.id)).count == values.count,
            values.allSatisfy({
                isBoundedIdentifier($0.id) &&
                    $0.account == account &&
                    ($0.marketId.map(isRuntimeUInt32) ?? false) &&
                    isValidRuntimeUInt32List(
                        $0.marketIds,
                        primary: $0.marketId
                    ) &&
                    $0.market != nil &&
                    $0.market?.marketId == $0.marketId &&
                    [
                        $0.collateralUsd,
                        $0.shares,
                        $0.sharesIn,
                        $0.sharesOut,
                        $0.executionPrice,
                        $0.feeUsd,
                    ].allSatisfy({ isNonNegative($0) }) &&
                    ($0.blockNumber.map({ $0 >= 0 }) ?? false) &&
                    $0.blockHash.flatMap(
                        PIHistoryCheckpointValidator.normalizedBlockHash
                    ) != nil &&
                    $0.extrinsicHash.flatMap(
                        PIHistoryCheckpointValidator.normalizedTransactionHash
                    ) != nil &&
                    isBoundedOptionalLabel($0.side) &&
                    isBoundedOptionalLabel($0.outcome) &&
                    isBoundedOptionalLabel($0.timestamp)
            })
        else {
            throw PIIndexerError.invalidChainIdentity
        }
        try validateMarkets(values.compactMap(\.market))
    }

    static func validatedPendingTransactionHashes(
        _ transactionHashes: [String]
    ) throws -> [String] {
        guard (1 ... 100).contains(transactionHashes.count) else {
            throw PIIndexerError.invalidResponse
        }
        let canonicalHashes = transactionHashes.compactMap(
            PIHistoryCheckpointValidator.normalizedTransactionHash
        )
        guard
            canonicalHashes.count == transactionHashes.count,
            Set(canonicalHashes).count == canonicalHashes.count
        else {
            throw PIIndexerError.invalidResponse
        }
        return canonicalHashes
    }

    private static func isRuntimeUInt32(_ value: Int) -> Bool {
        UInt32(exactly: value) != nil
    }

    private static func isValidRuntimeUInt32List(
        _ values: [Int]?,
        primary: Int?
    ) -> Bool {
        guard let values else {
            return true
        }
        return values.count <= PolkamarktRuntimeContract.maximumBatchClaims &&
            Set(values).count == values.count &&
            values.allSatisfy(isRuntimeUInt32) &&
            (values.isEmpty || values.first == primary)
    }

    static func validateMobileConfig(_ config: PIMobileConfig) throws {
        guard
            config.blockExplorerUrl.scheme?.lowercased() == "https",
            config.blockExplorerUrl.absoluteString.utf8.count <= 2_048,
            (config.blockExplorerUrl.absoluteString.removingPercentEncoding ?? "")
                .contains("{transaction}"),
            (1 ... 100).contains(config.nodes.count),
            Set(config.nodes.map({
                "\($0.name)\u{0}\($0.address.absoluteString)"
            })).count == config.nodes.count,
            config.nodes.allSatisfy({
                !$0.name.isEmpty &&
                    $0.name ==
                        $0.name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ) &&
                    $0.name.utf8.count <= 256 &&
                    $0.address.scheme?.lowercased() == "wss" &&
                    $0.address.host != nil &&
                    $0.address.absoluteString.utf8.count <= 2_048
            }),
            config.substrateTypesUrl.map({
                $0.scheme?.lowercased() == "https" &&
                    $0.absoluteString.utf8.count <= 2_048
            }) ?? true,
            !config.nexusSendsAvailable || config.nexusAvailable,
            !config.polkamarktMutationsAvailable || config.polkamarktVisible
        else {
            throw PIIndexerError.invalidResponse
        }
    }

    static func validatePolkamarktSignals(
        _ signals: PIPolkamarktSignals
    ) throws {
        let pointLabels = signals.liquiditySeries.map(\.label)
        let answers = signals.answerBreakdown.map(\.answer)
        guard
            signals.activeMarkets >= 0,
            signals.activeAccounts >= 0,
            signals.accuracySummary.map({
                $0.accuracyPercent.isFinite &&
                    (0 ... 100).contains($0.accuracyPercent)
            }) ?? true,
            !signals.totalVolumeUsd.rawValue.hasPrefix("-"),
            !signals.liquidityUsd.rawValue.hasPrefix("-"),
            signals.liquiditySeries.count <= 1_000,
            signals.answerBreakdown.count <= 1_000,
            Set(pointLabels).count == pointLabels.count,
            Set(answers).count == answers.count,
            pointLabels.allSatisfy({
                !$0.isEmpty &&
                    $0 == $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) &&
                    $0.utf8.count <= 256
            }),
            signals.answerBreakdown.allSatisfy({
                !$0.answer.isEmpty &&
                    $0.answer == $0.answer.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) &&
                    $0.answer.utf8.count <= 256 &&
                    !$0.volumeUsd.rawValue.hasPrefix("-") &&
                    $0.markets >= 0
            }),
            signals.liquiditySeries.allSatisfy({
                !$0.value.rawValue.hasPrefix("-")
            })
        else {
            throw PIIndexerError.invalidResponse
        }
    }

    static func validateAssets(_ values: [PIAsset]) throws {
        guard values.allSatisfy({ asset in
            (asset.priceChangeDay?.isFinite ?? true) &&
                (asset.priceChangeWeek?.isFinite ?? true) &&
            [
                asset.priceUSD,
                asset.supply,
                asset.liquidity,
                asset.liquidityBooks,
                asset.volumeDayUSD,
                asset.volumeWeekUSD,
            ].allSatisfy({ isNonNegative($0) })
        }) else {
            throw PIIndexerError.invalidQuantity
        }
    }

    static func validatePools(_ values: [PIPoolXYK]) throws {
        guard values.allSatisfy({ pool in
            [pool.baseAssetId, pool.targetAssetId].allSatisfy({
                $0.map({ isBoundedIdentifier($0) }) ?? true
            }) &&
                [
                    pool.baseAssetReserves,
                    pool.targetAssetReserves,
                    pool.priceUSD,
                    pool.strategicBonusApy,
                    pool.poolTokenSupply,
                    pool.poolTokenPriceUSD,
                    pool.liquidityUSD,
                ].allSatisfy({ isNonNegative($0) })
        }) else {
            throw PIIndexerError.invalidQuantity
        }
    }

    static func validateReferrerRewards(
        _ values: [PIReferrerReward],
        account: String,
        qualification: PIReadQualification?
    ) throws {
        guard
            isBoundedIdentifier(account),
            values.allSatisfy({
                $0.referrer == account &&
                    $0.referral.map({ isBoundedIdentifier($0) }) == true &&
                    $0.amount != nil &&
                    isNonNegative($0.amount)
            })
        else {
            throw PIIndexerError.invalidChainIdentity
        }
        let heights = try values.map {
            try exactNonNegativeInt($0.blockHeight)
        }
        try validateResponseHeights(
            heights,
            qualification: qualification
        )
    }

    private static func isNonNegative(_ value: PIQuantity?) -> Bool {
        value.map { !$0.rawValue.hasPrefix("-") } ?? true
    }

    private static func isPercentage(_ value: PIQuantity?) -> Bool {
        isNonNegative(value) && isAtMost(value, integerMaximum: "100")
    }

    private static func isUnitInterval(_ value: PIQuantity?) -> Bool {
        isNonNegative(value) && isAtMost(value, integerMaximum: "1")
    }

    private static func isAtMost(
        _ value: PIQuantity?,
        integerMaximum: String
    ) -> Bool {
        guard let value else {
            return true
        }
        let parts = value.rawValue.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let integer = String(parts[0])
        let fraction: Substring = parts.count == 2 ? parts[1] : ""
        if integer.utf8.count != integerMaximum.utf8.count {
            return integer.utf8.count < integerMaximum.utf8.count
        }
        if integer != integerMaximum {
            return integer.lexicographicallyPrecedes(integerMaximum)
        }
        return fraction.allSatisfy { $0 == "0" }
    }

    private static func isBasisPoints(_ value: Int?) -> Bool {
        value.map { (0 ... 10_000).contains($0) } ?? true
    }

    private static func isBoundedOptionalLabel(_ value: String?) -> Bool {
        value.map {
            !$0.isEmpty &&
                $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) &&
                $0.utf8.count <= 512
        } ?? true
    }

    private static func isBoundedRequiredLabel(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return isBoundedOptionalLabel(value)
    }

    private static func isBoundedIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.utf8.count <= 512
    }

    private static func isBoundedCursor(_ value: String?) -> Bool {
        value.map {
            !$0.isEmpty &&
                $0.utf8.count <= maximumCursorBytes &&
                $0.unicodeScalars.allSatisfy {
                    !CharacterSet.controlCharacters.contains($0)
                }
        } ?? true
    }

    private static func exactNonNegativeInt(_ value: String?) throws -> Int? {
        guard let value else {
            return nil
        }
        guard
            !value.isEmpty,
            value.utf8.count <= 19,
            value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
            value == "0" || value.first != "0",
            let parsed = Int(value)
        else {
            throw PIIndexerError.invalidResponse
        }
        return parsed
    }

    func mobileConfig(requireLive: Bool = false) async throws -> PIMobileConfig {
        let qualified = try await qualifiedMobileConfig(
            requireLive: requireLive
        )
        return qualified.value
    }

    func qualifiedMobileConfig(
        requireLive: Bool = false
    ) async throws -> PIQualifiedRead<PIMobileConfig> {
        struct Payload: Decodable { let mobileConfig: PIMobileConfig }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileConfig",
            query: """
            query MobileConfig {
              mobileConfig {
                blockExplorerUrl substrateTypesUrl soracard
                nodes { name address }
                nexusAvailable nexusSendsAvailable
                polkamarktVisible polkamarktMutationsAvailable
                tairaDefaultVisible
              }
            }
            """,
            cachePolicy: requireLive
                ? .none
                : .offline(maximumAge: TimeInterval(7 * 24 * 60 * 60)),
            validateResponse: { payload, _ in
                try Self.validateMobileConfig(payload.mobileConfig)
            }
        )
        return PIQualifiedRead(
            value: result.value.mobileConfig,
            qualification: result.qualification
        )
    }

    /// Explicit fail-closed gate for callers that require a PI account-balance query. Never
    /// interpret the schema-v1 untyped `account` JSON object as a balance response.
    func requireTypedAccountBalancesCapability(
        requireLive: Bool = true
    ) async throws {
        let config = try await mobileConfig(requireLive: requireLive)
        guard config.typedAccountBalancesAvailable else {
            throw PIIndexerError.typedAccountBalancesUnavailable
        }
    }

    func assets(first: Int = 100, after: String? = nil) async throws -> PIConnection<PIAsset> {
        try await assetsRead(first: first, after: after).value
    }

    private func assetsRead(
        first: Int,
        after: String?
    ) async throws -> PIQualifiedRead<PIConnection<PIAsset>> {
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let assets: PIConnection<PIAsset> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileAssets",
            query: """
            query MobileAssets($first: Int!, $after: Cursor) {
              assets(first: $first, after: $after, orderBy: [ID_ASC]) {
                nodes {
                  id priceUSD supply liquidity liquidityBooks priceChangeDay
                  priceChangeWeek volumeDayUSD volumeWeekUSD
                }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact(["first": first, "after": after]),
            cachePolicy: .offline(maximumAge: TimeInterval(24 * 60 * 60)),
            validateResponse: { payload, _ in
                try Self.validateConnectionPage(
                    payload.assets,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                try Self.validateAssets(payload.assets.values)
            }
        )
        return PIQualifiedRead(
            value: result.value.assets,
            qualification: result.qualification
        )
    }

    func allAssets(
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIAsset] {
        try await collectQualifiedPages(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.assetsRead(first: pageSize, after: after)
        }
    }

    func poolXYKs(
        first: Int = 100,
        after: String? = nil
    ) async throws -> PIConnection<PIPoolXYK> {
        try await poolXYKsRead(first: first, after: after).value
    }

    private func poolXYKsRead(
        first: Int,
        after: String?
    ) async throws -> PIQualifiedRead<PIConnection<PIPoolXYK>> {
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let poolXYKs: PIConnection<PIPoolXYK> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobilePoolXYKs",
            query: """
            query MobilePoolXYKs($first: Int!, $after: Cursor) {
              poolXYKs(first: $first, after: $after, orderBy: [ID_ASC]) {
                nodes {
                  id baseAssetId targetAssetId baseAssetReserves targetAssetReserves
                  priceUSD strategicBonusApy poolTokenSupply poolTokenPriceUSD liquidityUSD
                }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact(["first": first, "after": after]),
            cachePolicy: .offline(maximumAge: TimeInterval(24 * 60 * 60)),
            validateResponse: { payload, _ in
                try Self.validateConnectionPage(
                    payload.poolXYKs,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                try Self.validatePools(payload.poolXYKs.values)
            }
        )
        return PIQualifiedRead(
            value: result.value.poolXYKs,
            qualification: result.qualification
        )
    }

    func allPoolXYKs(
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIPoolXYK] {
        try await collectQualifiedPages(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.poolXYKsRead(first: pageSize, after: after)
        }
    }

    func referrerRewards(
        address: String,
        first: Int = 100,
        after: String? = nil
    ) async throws -> PIConnection<PIReferrerReward> {
        try await referrerRewardsRead(
            address: address,
            first: first,
            after: after
        ).value
    }

    private func referrerRewardsRead(
        address: String,
        first: Int,
        after: String?
    ) async throws -> PIQualifiedRead<PIConnection<PIReferrerReward>> {
        let address = try validatedIdentifier(address)
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable {
            let referrerRewards: PIConnection<PIReferrerReward>
        }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileReferrerRewards",
            query: """
            query MobileReferrerRewards(
              $first: Int!
              $after: Cursor
              $filter: ReferrerRewardFilter
            ) {
              referrerRewards(
                first: $first
                after: $after
                orderBy: [TIMESTAMP_DESC, ID_DESC]
                filter: $filter
              ) {
                nodes { id referral referrer blockHeight timestamp amount }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact([
                "first": first,
                "after": after,
                "filter": ["referrer": ["equalTo": address]]
            ]),
            cachePolicy: .offline(maximumAge: TimeInterval(24 * 60 * 60)),
            validateResponse: { payload, qualification in
                try Self.validateConnectionPage(
                    payload.referrerRewards,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                try Self.validateReferrerRewards(
                    payload.referrerRewards.values,
                    account: address,
                    qualification: qualification
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.referrerRewards,
            qualification: result.qualification
        )
    }

    func allReferrerRewards(
        address: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIReferrerReward] {
        try await collectQualifiedPages(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.referrerRewardsRead(
                address: address,
                first: pageSize,
                after: after
            )
        }
    }

    func history(
        address: String,
        first: Int,
        after: String? = nil
    ) async throws -> PIConnection<PIHistoryElement> {
        try await historyRead(
            address: address,
            first: first,
            after: after
        ).value
    }

    func qualifiedHistory(
        address: String,
        first: Int,
        after: String? = nil
    ) async throws -> PIQualifiedRead<PIConnection<PIHistoryElement>> {
        try await historyRead(
            address: address,
            first: first,
            after: after
        )
    }

    /// Compatibility adapter for the legacy numbered-page UI. PI itself is
    /// cursor-only: every requested page is reached by walking from page one,
    /// while rejecting cursor replay, item overlap, count drift, and a change
    /// of live checkpoint/provenance anywhere in the logical traversal.
    func qualifiedHistoryPage(
        address: String,
        first: Int,
        page: Int,
        maximumPages: Int = maximumHistoryPages
    ) async throws -> PIQualifiedRead<PIConnection<PIHistoryElement>> {
        try Self.validateHistoryPage(page, maximumPages: maximumPages)
        try validate(pageSize: first)

        var cursor: String?
        var seenCursors = Set<String>()
        var seenItemIdentities = Set<String>()
        var expectedTotalCount: Int?
        var expectedQualification: PIReadQualification?
        var consumedCount = 0

        for currentPage in 1 ... page {
            let read = try await historyRead(
                address: address,
                first: first,
                after: cursor
            )
            guard let qualification = read.qualification else {
                throw PIIndexerError.missingChainIdentityCapability
            }
            if let expectedQualification {
                guard qualification == expectedQualification else {
                    throw PIIndexerError.staleCheckpoint
                }
            } else {
                expectedQualification = qualification
            }

            let connection = read.value
            guard
                expectedTotalCount.map({ $0 == connection.totalCount }) ?? true
            else {
                throw PIIndexerError.invalidResponse
            }
            expectedTotalCount = connection.totalCount

            let identities = connection.values.compactMap {
                PIHistoryCheckpointValidator.canonicalHistoryIdentifier($0.id)
            }
            guard
                identities.count == connection.values.count,
                identities.allSatisfy({
                    seenItemIdentities.insert($0).inserted
                })
            else {
                throw PIIndexerError.repeatedPage
            }
            let (nextConsumedCount, countOverflow) = consumedCount
                .addingReportingOverflow(connection.values.count)
            guard
                !countOverflow,
                nextConsumedCount <= connection.totalCount,
                connection.pageInfo.hasNextPage
                    ? nextConsumedCount < connection.totalCount
                    : nextConsumedCount == connection.totalCount
            else {
                throw PIIndexerError.invalidResponse
            }
            consumedCount = nextConsumedCount

            if currentPage == page {
                return read
            }
            guard connection.pageInfo.hasNextPage else {
                return PIQualifiedRead(
                    value: PIConnection(
                        nodes: [],
                        edges: nil,
                        pageInfo: PIPageInfo(
                            hasNextPage: false,
                            hasPreviousPage: true,
                            startCursor: nil,
                            endCursor: nil
                        ),
                        totalCount: connection.totalCount
                    ),
                    qualification: expectedQualification
                )
            }
            guard
                let next = connection.pageInfo.endCursor,
                Self.isBoundedCursor(next),
                next != cursor,
                seenCursors.insert(next).inserted
            else {
                throw PIIndexerError.repeatedCursor
            }
            cursor = next
        }
        throw PIIndexerError.paginationLimit
    }

    private func historyRead(
        address: String,
        first: Int,
        after: String?,
        transactionHashes: [String]? = nil
    ) async throws -> PIQualifiedRead<PIConnection<PIHistoryElement>> {
        let address = try validatedIdentifier(address)
        try validate(pageSize: first)
        try Self.validateHistoryPagination(after: after)
        struct Payload: Decodable { let historyElements: PIConnection<PIHistoryElement> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileHistory",
            query: """
            query MobileHistory(
              $first: Int!
              $after: Cursor
              $filter: HistoryElementFilter
            ) {
              historyElements(
                first: $first
                after: $after
                orderBy: [TIMESTAMP_DESC, ID_DESC]
                filter: $filter
              ) {
                nodes {
                  id type timestamp blockHash blockHeight module method address
                  networkFee execution data dataFrom dataTo dataAssets callNames
                  calls { nodes { module method data } }
                }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact([
                "first": first,
                "after": after,
                // Bind public timestamp-ordered history to every exact account
                // role PI indexes. Incoming transfers and synthetic bridge
                // mints may identify the wallet only through dataFrom/dataTo.
                "filter": compact([
                    "or": [
                        ["address": ["equalTo": address]],
                        ["dataFrom": ["equalTo": address]],
                        ["dataTo": ["equalTo": address]],
                    ],
                    "id": transactionHashes.map { ["in": $0] },
                    "type": [
                        "in": [
                            "CALL",
                            "TRANSFER",
                            "SWAP",
                            "LIQUIDITY",
                            "REFERRAL",
                            "REWARD"
                        ]
                    ]
                ])
            ]),
            // History has a separate account-bound cache that is persisted
            // only after canonical SORA RPC block-hash validation. Reusing a
            // raw GraphQL page here would lose that proof and could bind it to
            // a different concurrent health checkpoint.
            cachePolicy: .none,
            validateResponse: { payload, qualification in
                try Self.validateConnectionPage(
                    payload.historyElements,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: {
                        PIHistoryCheckpointValidator
                            .canonicalHistoryIdentifier($0.id) ?? ""
                    }
                )
                try Self.validateAccountHistory(
                    payload.historyElements.values,
                    account: address,
                    expectedTransactionHashes: transactionHashes.map {
                        Set($0)
                    }
                )
                try Self.validateResponseHeights(
                    payload.historyElements.values.map(\.blockHeight),
                    qualification: qualification
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.historyElements,
            qualification: result.qualification
        )
    }

    /// Looks up only the bounded pending hash set for one exact account.
    ///
    /// Restart recovery must not depend on exhausting a trader's lifetime
    /// history, which can legitimately exceed the mobile pagination limit.
    func qualifiedHistoryByTransactionHashes(
        address: String,
        transactionHashes: [String]
    ) async throws -> PIQualifiedRead<[PIHistoryElement]> {
        guard
            !address.isEmpty,
            address == address.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            address.utf8.count <= 512
        else {
            throw PIIndexerError.invalidResponse
        }
        let canonicalHashes =
            try Self.validatedPendingTransactionHashes(transactionHashes)
        let expectedHashes = Set(canonicalHashes)
        let read = try await historyRead(
            address: address,
            first: canonicalHashes.count,
            after: nil,
            transactionHashes: canonicalHashes
        )
        let page = read.value
        let values = page.values
        let returnedHashes = values.compactMap {
            PIHistoryCheckpointValidator.normalizedTransactionHash($0.id)
        }
        let allValuesBelongToRequestedAccount = values.allSatisfy { element in
            guard
                let hash = PIHistoryCheckpointValidator
                    .normalizedTransactionHash(element.id),
                expectedHashes.contains(hash)
            else {
                return false
            }
            return
                element.address == address ||
                element.dataFrom == address ||
                element.dataTo == address
        }
        guard
            page.totalCount == values.count,
            !page.pageInfo.hasNextPage,
            !page.pageInfo.hasPreviousPage,
            returnedHashes.count == values.count,
            Set(returnedHashes).count == returnedHashes.count,
            Set(returnedHashes).isSubset(of: expectedHashes),
            allValuesBelongToRequestedAccount
        else {
            throw PIIndexerError.invalidChainIdentity
        }
        return PIQualifiedRead(
            value: values,
            qualification: read.qualification
        )
    }

    func allHistory(
        address: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIHistoryElement] {
        try await qualifiedAllHistory(
            address: address,
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    func qualifiedAllHistory(
        address: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> PIQualifiedRead<[PIHistoryElement]> {
        try await collectQualifiedPagesRead(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: {
                PIHistoryCheckpointValidator
                    .canonicalHistoryIdentifier($0.id) ?? ""
            }
        ) { after in
            try await self.historyRead(
                address: address,
                first: pageSize,
                after: after
            )
        }
    }

    func markets(
        first: Int = 50,
        after: String? = nil,
        status: PolkamarktMarketStatus? = nil
    ) async throws -> PIConnection<PIMarket> {
        try await marketsRead(
            first: first,
            after: after,
            status: status
        ).value
    }

    private func marketsRead(
        first: Int,
        after: String?,
        status: PolkamarktMarketStatus?
    ) async throws -> PIQualifiedRead<PIConnection<PIMarket>> {
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let markets: PIConnection<PIMarket> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobilePolkamarktMarkets",
            query: """
            query MobilePolkamarktMarkets($first: Int!, $after: Cursor, $filter: MarketFilter) {
              markets(first: $first, after: $after, orderBy: [ID_ASC], filter: $filter) {
                edges {
                  cursor
                  node {
                    id marketId conditionId title category tags description metadataUri
                    rulesUri resolutionSource closeBlock status mechanism creator
                    collateralAsset creatorFees liquidityUSD volumeUSD probability
                    priceYes priceNo virtualDepth dpmCollateral realYesShares
                    realNoShares marginalYesPriceBps marginalNoPriceBps collateral
                    yesShares noShares resolutionOutcome resolutionEvidenceUri
                    cancellationEvidenceUri governanceUrl updatedAtBlock timestamp
                  }
                }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact([
                "first": first,
                "after": after,
                "filter": status.map {
                    ["status": ["equalTo": $0.rawValue]]
                }
            ]),
            cachePolicy: .offline(maximumAge: TimeInterval(6 * 60 * 60)),
            validateResponse: { payload, qualification in
                try Self.validateConnectionPage(
                    payload.markets,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                try Self.validateMarkets(
                    payload.markets.values,
                    expectedStatus: status
                )
                try Self.validateUniqueRuntimeMarketIds(
                    payload.markets.values
                )
                try Self.validateResponseHeights(
                    payload.markets.values.map(\.updatedAtBlock),
                    qualification: qualification
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.markets,
            qualification: result.qualification
        )
    }

    func allMarkets(
        status: PolkamarktMarketStatus? = nil,
        pageSize: Int = 50,
        maximumPages: Int = 20
    ) async throws -> [PIMarket] {
        try await qualifiedAllMarkets(
            status: status,
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    func qualifiedAllMarkets(
        status: PolkamarktMarketStatus? = nil,
        pageSize: Int = 50,
        maximumPages: Int = 20
    ) async throws -> PIQualifiedRead<[PIMarket]> {
        let result = try await collectQualifiedPagesRead(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.marketsRead(
                first: pageSize,
                after: after,
                status: status
            )
        }
        // GraphQL row IDs are not the transaction identity. Revalidate the
        // fully collected catalog so duplicates split across pages cannot map
        // two enrichment rows onto one runtime marketId.
        try Self.validateUniqueRuntimeMarketIds(result.value)
        return result
    }

    func marketSnapshots(
        marketId: Int,
        first: Int = 100,
        after: String? = nil
    ) async throws -> PIConnection<PIMarketSnapshot> {
        try await qualifiedMarketSnapshots(
            marketId: marketId,
            first: first,
            after: after
        ).value
    }

    func qualifiedMarketSnapshots(
        marketId: Int,
        first: Int = 100,
        after: String? = nil
    ) async throws -> PIQualifiedRead<PIConnection<PIMarketSnapshot>> {
        guard UInt32(exactly: marketId) != nil else {
            throw PIIndexerError.invalidResponse
        }
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let marketSnapshots: PIConnection<PIMarketSnapshot> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobilePolkamarktSnapshots",
            query: """
            query MobilePolkamarktSnapshots(
              $first: Int!
              $after: Cursor
              $filter: MarketSnapshotFilter
            ) {
              marketSnapshots(first: $first, after: $after, orderBy: [TIMESTAMP_ASC, ID_ASC], filter: $filter) {
                edges {
                  cursor
                  node {
                    id marketId timestamp blockHeight type probability priceYes priceNo
                    virtualDepth dpmCollateral realYesShares realNoShares collateral
                    yesShares noShares liquidityUSD volumeUSD status
                  }
                }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact([
                "first": first,
                "after": after,
                "filter": [
                    "marketId": ["equalTo": marketId],
                    "type": ["equalTo": "DEFAULT"]
                ]
            ]),
            cachePolicy: .offline(maximumAge: TimeInterval(6 * 60 * 60)),
            validateResponse: { payload, qualification in
                try Self.validateConnectionPage(
                    payload.marketSnapshots,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                let values = payload.marketSnapshots.values
                try Self.validateMarketSnapshots(values, marketId: marketId)
                try Self.validateResponseHeights(
                    values.map(\.blockHeight),
                    qualification: qualification
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.marketSnapshots,
            qualification: result.qualification
        )
    }

    func allMarketSnapshots(
        marketId: Int,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIMarketSnapshot] {
        try await qualifiedAllMarketSnapshots(
            marketId: marketId,
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    func qualifiedAllMarketSnapshots(
        marketId: Int,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> PIQualifiedRead<[PIMarketSnapshot]> {
        let read = try await collectQualifiedPagesRead(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.qualifiedMarketSnapshots(
                marketId: marketId,
                first: pageSize,
                after: after
            )
        }
        try Self.validateMarketSnapshots(read.value, marketId: marketId)
        return read
    }

    func accountPositions(
        account: String,
        first: Int = 100,
        after: String? = nil
    ) async throws -> PIConnection<PIAccountPosition> {
        try await accountPositionsRead(
            account: account,
            first: first,
            after: after
        ).value
    }

    private func accountPositionsRead(
        account: String,
        first: Int,
        after: String?
    ) async throws -> PIQualifiedRead<PIConnection<PIAccountPosition>> {
        let account = try validatedIdentifier(account)
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let accountPositions: PIConnection<PIAccountPosition> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobilePolkamarktPositions",
            query: Self.positionsQuery,
            variables: compact([
                "first": first,
                "after": after,
                "filter": ["account": ["equalTo": account]]
            ]),
            cachePolicy: .offline(maximumAge: TimeInterval(24 * 60 * 60)),
            validateResponse: { payload, qualification in
                try Self.validateConnectionPage(
                    payload.accountPositions,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                let values = payload.accountPositions.values
                try Self.validateAccountPositions(values, account: account)
                try Self.validateResponseHeights(
                    values.map { $0.market?.updatedAtBlock },
                    qualification: qualification
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.accountPositions,
            qualification: result.qualification
        )
    }

    func allAccountPositions(
        account: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIAccountPosition] {
        try await qualifiedAllAccountPositions(
            account: account,
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    func qualifiedAllAccountPositions(
        account: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> PIQualifiedRead<[PIAccountPosition]> {
        try await collectQualifiedPagesRead(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.accountPositionsRead(
                account: account,
                first: pageSize,
                after: after
            )
        }
    }

    func accountTrades(
        account: String,
        first: Int = 100,
        after: String? = nil
    ) async throws -> PIConnection<PIAccountTrade> {
        try await accountTradesRead(
            account: account,
            first: first,
            after: after
        ).value
    }

    private func accountTradesRead(
        account: String,
        first: Int,
        after: String?
    ) async throws -> PIQualifiedRead<PIConnection<PIAccountTrade>> {
        let account = try validatedIdentifier(account)
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let accountTrades: PIConnection<PIAccountTrade> }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobilePolkamarktTrades",
            query: Self.tradesQuery,
            variables: compact([
                "first": first,
                "after": after,
                "filter": ["account": ["equalTo": account]]
            ]),
            cachePolicy: .offline(maximumAge: TimeInterval(24 * 60 * 60)),
            validateResponse: { payload, qualification in
                try Self.validateConnectionPage(
                    payload.accountTrades,
                    requestedSize: first,
                    hasPriorPage: after != nil,
                    itemIdentity: { $0.id }
                )
                let values = payload.accountTrades.values
                try Self.validateAccountTrades(values, account: account)
                try Self.validateResponseHeights(
                    values.flatMap {
                        [$0.blockNumber, $0.market?.updatedAtBlock]
                    },
                    qualification: qualification
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.accountTrades,
            qualification: result.qualification
        )
    }

    func allAccountTrades(
        account: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIAccountTrade] {
        try await qualifiedAllAccountTrades(
            account: account,
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    func qualifiedAllAccountTrades(
        account: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> PIQualifiedRead<[PIAccountTrade]> {
        try await collectQualifiedPagesRead(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: { $0.id }
        ) { after in
            try await self.accountTradesRead(
                account: account,
                first: pageSize,
                after: after
            )
        }
    }

    func polkamarktSignals() async throws -> PIPolkamarktSignals {
        try await qualifiedPolkamarktSignals().value
    }

    func qualifiedPolkamarktSignals()
        async throws -> PIQualifiedRead<PIPolkamarktSignals>
    {
        struct Payload: Decodable { let polkamarktSignals: PIPolkamarktSignals }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobilePolkamarktSignals",
            query: """
            query MobilePolkamarktSignals {
              polkamarktSignals {
                totalVolumeUsd activeMarkets activeAccounts liquidityUsd
                liquiditySeries { label value }
                answerBreakdown { answer volumeUsd markets }
                accuracySummary { accuracyPercent }
              }
            }
            """,
            cachePolicy: .offline(maximumAge: TimeInterval(6 * 60 * 60)),
            validateResponse: { payload, _ in
                try Self.validatePolkamarktSignals(
                    payload.polkamarktSignals
                )
            }
        )
        return PIQualifiedRead(
            value: result.value.polkamarktSignals,
            qualification: result.qualification
        )
    }

    private enum CachePolicy {
        case none
        case offline(maximumAge: TimeInterval)
    }

    private func execute<Payload: Decodable>(
        operationName: String,
        query: String,
        variables: [String: Any] = [:],
        cachePolicy: CachePolicy,
        validateResponse: (Payload, PIReadQualification?) throws -> Void = { _, _ in }
    ) async throws -> Payload {
        try await executeQualified(
            operationName: operationName,
            query: query,
            variables: variables,
            cachePolicy: cachePolicy,
            validateResponse: validateResponse
        ).value
    }

    private func executeQualified<Payload: Decodable>(
        operationName: String,
        query: String,
        variables: [String: Any] = [:],
        cachePolicy: CachePolicy,
        validateResponse: (Payload, PIReadQualification?) throws -> Void = { _, _ in }
    ) async throws -> PIQualifiedRead<Payload> {
        // Legacy operation adapters still pass their configured base URL into this client. The
        // consolidated PI service is nevertheless an exact production boundary: a stale or
        // compromised config value must not substitute another GraphQL origin.
        try Self.validateProductionEndpoint(endpoint)
        let body = try JSONSerialization.data(
            withJSONObject: [
                "operationName": operationName,
                "query": query,
                "variables": variables
            ],
            options: [.sortedKeys]
        )
        try Self.validateRequestBody(body)
        var cacheIdentity = Data(endpoint.absoluteString.utf8)
        cacheIdentity.append(0)
        cacheIdentity.append(body)
        let cacheDigest = Data(SHA256.hash(data: cacheIdentity))
            .map { String(format: "%02x", $0) }
            .joined()
        let cacheKey = "\(operationName)-\(cacheDigest)"

        do {
            let liveHealth: PIHealth?
            if operationName != "MobileHealth" {
                // A cached health record is not sufficient to authorize fresh
                // indexed data because its finalized checkpoint may be stale.
                // If the live preflight is unreachable, the outer operation
                // may still use its own bounded offline cache.
                liveHealth = try await health(requireLive: true)
            } else {
                liveHealth = nil
            }
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = body
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            request.setValue(
                "no-store, no-cache, max-age=0",
                forHTTPHeaderField: "Cache-Control"
            )
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let (bytes, response) = try await session.bytes(for: request)
            let http = try Self.validateHTTPResponse(
                response,
                endpoint: endpoint
            )
            try Self.validateExpectedResponseLength(
                http.expectedContentLength
            )
            var data = Data()
            if http.expectedContentLength > 0 {
                data.reserveCapacity(Int(http.expectedContentLength))
            }
            for try await byte in bytes {
                guard data.count < Self.maximumResponseBytes else {
                    throw PIIndexerError.responseTooLarge
                }
                data.append(byte)
            }
            let payload = try decode(Payload.self, data: data)
            if let liveHealth {
                // Attribute the response only when PI's indexed checkpoint did
                // not change between the live health preflight and postflight.
                // This is deliberately per request; a 30-second health cache
                // cannot prove which checkpoint produced an individual page.
                let postflightHealth = try await health(requireLive: true)
                try Self.validateStableResponseCheckpoint(
                    preflight: liveHealth,
                    postflight: postflightHealth
                )
            }
            let qualification = liveHealth.map {
                PIReadQualification(health: $0, source: .live)
            }
            // A decoded response is not cache-eligible until all operation-
            // specific identity and checkpoint bounds have passed.
            try validateResponse(payload, qualification)
            if case .offline = cachePolicy {
                await cache.save(data, health: liveHealth, key: cacheKey)
            }
            return PIQualifiedRead(
                value: payload,
                qualification: qualification
            )
        } catch let liveError as PIIndexerError {
            guard
                liveError.allowsOfflineFallback,
                case let .offline(maximumAge) = cachePolicy,
                let entry = await cache.load(
                    key: cacheKey,
                    maximumAge: maximumAge
                )
            else {
                throw liveError
            }
            do {
                return try qualifiedCachedRead(
                    entry,
                    operationName: operationName,
                    validateResponse: validateResponse
                )
            } catch {
                await cache.remove(key: cacheKey)
                throw liveError
            }
        } catch let liveError as URLError {
            guard
                Self.allowsOfflineTransportFallback(liveError),
                case let .offline(maximumAge) = cachePolicy,
                let entry = await cache.load(
                    key: cacheKey,
                    maximumAge: maximumAge
                )
            else {
                throw liveError
            }
            do {
                return try qualifiedCachedRead(
                    entry,
                    operationName: operationName,
                    validateResponse: validateResponse
                )
            } catch {
                await cache.remove(key: cacheKey)
                throw liveError
            }
        } catch {
            // Schema/decoding/cancellation/programming failures are not
            // offline conditions and must never be hidden by cached data.
            throw error
        }
    }

    static func validateHTTPResponse(
        _ response: URLResponse,
        endpoint: URL
    ) throws -> HTTPURLResponse {
        guard
            let http = response as? HTTPURLResponse,
            http.url == endpoint,
            http.url?.absoluteString == endpoint.absoluteString
        else {
            throw PIIndexerError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw PIIndexerError.httpStatus(http.statusCode)
        }
        guard http.mimeType?.lowercased() == "application/json" else {
            throw PIIndexerError.invalidResponse
        }
        if let contentEncoding = http.value(
            forHTTPHeaderField: "Content-Encoding"
        ) {
            guard
                contentEncoding == contentEncoding.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                contentEncoding.lowercased() == "identity"
            else {
                throw PIIndexerError.invalidResponse
            }
        }
        return http
    }

    private func qualifiedCachedRead<Payload: Decodable>(
        _ entry: PIResponseCache.Entry,
        operationName: String,
        validateResponse: (Payload, PIReadQualification?) throws -> Void
    ) throws -> PIQualifiedRead<Payload> {
        let payload = try decode(Payload.self, data: entry.payload)
        guard operationName != "MobileHealth" else {
            try validateResponse(payload, nil)
            return PIQualifiedRead(value: payload, qualification: nil)
        }
        guard let health = entry.health else {
            // Payload-only entries from an older app cannot prove which PI
            // checkpoint produced them and are deliberately not reusable.
            throw PIIndexerError.missingChainIdentityCapability
        }
        let savedAt = entry.savedAt.timeIntervalSince1970
        guard
            savedAt.isFinite,
            savedAt >= 0,
            savedAt <= Double(Int.max)
        else {
            throw PIIndexerError.invalidResponse
        }
        try Self.validateHealth(
            health,
            nowEpochSeconds: Int(savedAt.rounded(.towardZero))
        )
        let qualification = PIReadQualification(
            health: health,
            source: .cache
        )
        try validateResponse(payload, qualification)
        return PIQualifiedRead(
            value: payload,
            qualification: qualification
        )
    }

    static func allowsOfflineTransportFallback(_ error: URLError) -> Bool {
        switch error.code {
        case
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
            .resourceUnavailable,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    private func decode<Payload: Decodable>(
        _ type: Payload.Type,
        data: Data
    ) throws -> Payload {
        try PIStrictJSONAdmission.validate(data)
        let envelope = try decoder.decode(PIGraphQLResponse<Payload>.self, from: data)
        if let errors = envelope.errors, !errors.isEmpty {
            // Do not retain the raw GraphQL text in the thrown error: debug
            // descriptions are frequently logged by generic infrastructure.
            throw PIIndexerError.graphQLErrors
        }
        guard let payload = envelope.data else {
            throw PIIndexerError.missingData
        }
        return payload
    }

    private func validate(pageSize: Int) throws {
        guard (1 ... maximumPageSize).contains(pageSize) else {
            throw PIIndexerError.invalidPageSize
        }
    }

    private func validatedIdentifier(_ value: String) throws -> String {
        guard
            !value.isEmpty,
            value == value.trimmingCharacters(in: .whitespacesAndNewlines),
            value.utf8.count <= 512
        else {
            throw PIIndexerError.invalidResponse
        }
        return value
    }

    func collectPages<Node: Decodable & Equatable>(
        pageSize: Int,
        maximumPages: Int,
        loader: @escaping (String?) async throws -> PIConnection<Node>
    ) async throws -> [Node] {
        try await collectPagesCore(
            pageSize: pageSize,
            maximumPages: maximumPages,
            requireQualification: false
        ) { cursor in
            PIQualifiedRead(
                value: try await loader(cursor),
                qualification: nil
            )
        }.value
    }

    func collectQualifiedPages<Node: Decodable & Equatable>(
        pageSize: Int,
        maximumPages: Int,
        itemIdentity: ((Node) -> String)? = nil,
        loader: @escaping (String?) async throws ->
            PIQualifiedRead<PIConnection<Node>>
    ) async throws -> [Node] {
        try await collectQualifiedPagesRead(
            pageSize: pageSize,
            maximumPages: maximumPages,
            itemIdentity: itemIdentity,
            loader: loader
        ).value
    }

    func collectQualifiedPagesRead<Node: Decodable & Equatable>(
        pageSize: Int,
        maximumPages: Int,
        itemIdentity: ((Node) -> String)? = nil,
        loader: @escaping (String?) async throws ->
            PIQualifiedRead<PIConnection<Node>>
    ) async throws -> PIQualifiedRead<[Node]> {
        try await collectPagesCore(
            pageSize: pageSize,
            maximumPages: maximumPages,
            requireQualification: true,
            itemIdentity: itemIdentity,
            loader: loader
        )
    }

    private func collectPagesCore<Node: Decodable & Equatable>(
        pageSize: Int,
        maximumPages: Int,
        requireQualification: Bool,
        itemIdentity: ((Node) -> String)? = nil,
        loader: @escaping (String?) async throws ->
            PIQualifiedRead<PIConnection<Node>>
    ) async throws -> PIQualifiedRead<[Node]> {
        guard (1 ... 100).contains(maximumPages) else {
            throw PIIndexerError.paginationLimit
        }
        try validate(pageSize: pageSize)

        var result: [Node] = []
        var cursor: String?
        var seenCursors = Set<String>()
        var seenPages: [[Node]] = []
        var seenItemIdentities = Set<String>()
        var expectedTotalCount: Int?
        var expectedQualification: PIReadQualification?
        for _ in 0 ..< maximumPages {
            let read = try await loader(cursor)
            if requireQualification {
                guard let qualification = read.qualification else {
                    throw PIIndexerError.missingChainIdentityCapability
                }
                if let expectedQualification {
                    guard qualification == expectedQualification else {
                        // Never compose one logical result from cached/live
                        // pages or from different finalized PI checkpoints.
                        throw PIIndexerError.staleCheckpoint
                    }
                } else {
                    expectedQualification = qualification
                }
            }
            let page = read.value
            let values = page.values
            guard
                page.totalCount >= 0,
                values.count <= pageSize,
                (page.nodes != nil) != (page.edges != nil),
                page.pageInfo.hasPreviousPage == (cursor != nil),
                !page.pageInfo.hasNextPage || !values.isEmpty,
                Self.isBoundedCursor(page.pageInfo.startCursor),
                Self.isBoundedCursor(page.pageInfo.endCursor),
                expectedTotalCount.map({ $0 == page.totalCount }) ?? true
            else {
                throw PIIndexerError.invalidResponse
            }
            expectedTotalCount = page.totalCount
            if !values.isEmpty {
                guard !seenPages.contains(values) else {
                    throw PIIndexerError.repeatedPage
                }
                seenPages.append(values)
            }
            if let itemIdentity {
                let identities = values.map(itemIdentity)
                guard identities.allSatisfy({
                    !$0.isEmpty &&
                        $0 == $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ) &&
                        $0.utf8.count <= 4_096 &&
                        seenItemIdentities.insert($0).inserted
                }) else {
                    throw PIIndexerError.invalidResponse
                }
            }
            let (nextCount, countOverflow) = result.count
                .addingReportingOverflow(values.count)
            guard !countOverflow, nextCount <= page.totalCount else {
                throw PIIndexerError.invalidResponse
            }
            result.append(contentsOf: values)
            guard page.pageInfo.hasNextPage else {
                guard result.count == page.totalCount else {
                    throw PIIndexerError.invalidResponse
                }
                return PIQualifiedRead(
                    value: result,
                    qualification: expectedQualification
                )
            }
            guard let next = page.pageInfo.endCursor, !next.isEmpty else {
                throw PIIndexerError.invalidResponse
            }
            guard seenCursors.insert(next).inserted else {
                throw PIIndexerError.repeatedCursor
            }
            cursor = next
        }
        throw PIIndexerError.paginationLimit
    }

    private func compact(_ dictionary: [String: Any?]) -> [String: Any] {
        dictionary.compactMapValues { $0 }
    }

    private static let marketFragment = """
      id marketId conditionId title category status mechanism creator collateralAsset
      liquidityUSD volumeUSD probability priceYes priceNo resolutionOutcome updatedAtBlock
    """

    private static let positionsQuery = """
    query MobilePolkamarktPositions(
      $first: Int!
      $after: Cursor
      $filter: AccountPositionFilter
    ) {
      accountPositions(first: $first, after: $after, orderBy: [UPDATED_AT_DESC, ID_DESC], filter: $filter) {
        edges {
          cursor
          node {
            id account marketId outcome shares yesShares noShares netCollateralPaid
            costBasisUsd marketValueUsd realizedPnlUsd unrealizedPnlUsd
            claimablePayoutUsd isCreator status updatedAt
            market { \(marketFragment) }
          }
        }
        pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
        totalCount
      }
    }
    """

    private static let tradesQuery = """
    query MobilePolkamarktTrades(
      $first: Int!
      $after: Cursor
      $filter: AccountTradeFilter
    ) {
      accountTrades(first: $first, after: $after, orderBy: [TIMESTAMP_DESC, ID_DESC], filter: $filter) {
        edges {
          cursor
          node {
            id account marketId marketIds side outcome collateralUsd shares sharesIn sharesOut
            executionPrice feeUsd realizedPnlUsd timestamp blockNumber blockHash
            extrinsicHash market { \(marketFragment) }
          }
        }
        pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
        totalCount
      }
    }
    """
}
