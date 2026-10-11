// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import UIKit

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

    /// One step of the path to a JSON value: an object member or an array
    /// element.
    enum PathStep: Hashable {
        case key(String)
        case index(Int)
    }

    static let maximumCollectedNumberLexemes = 100_000

    /// The exact text of every JSON number that is an object member's value
    /// or an array element, by path. `JSONDecoder` only exposes numbers after
    /// converting them to `Double` or `Decimal`; a quantity PI sends as a
    /// JSON number is decoded from this text instead, so no digit is lost.
    static func numberLexemesByPath(
        in data: Data
    ) throws -> [[PathStep]: String] {
        guard data.count <= maximumBytes else {
            throw PIIndexerError.invalidResponse
        }
        var parser = Parser(
            bytes: Array(data),
            maximumDepth: maximumDepth,
            maximumTokens: maximumTokens
        )
        parser.numberLexemes = [:]
        try parser.parseDocument()
        return parser.numberLexemes ?? [:]
    }

    private struct Parser {
        let bytes: [UInt8]
        let maximumDepth: Int
        let maximumTokens: Int
        var index = 0
        var tokenCount = 0
        /// Non-nil only while collecting number lexemes.
        var numberLexemes: [[PathStep]: String]?
        var path: [PathStep] = []

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
                if
                    !path.isEmpty,
                    let collectedCount = numberLexemes?.count,
                    collectedCount <
                        PIStrictJSONAdmission.maximumCollectedNumberLexemes
                {
                    // Number tokens are ASCII by construction.
                    numberLexemes?[path] = String(
                        decoding: bytes[start ..< index],
                        as: UTF8.self
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
                let tracksPath = numberLexemes != nil
                if tracksPath { path.append(.key(name)) }
                try parseValue(
                    depth: depth + 1,
                    memberName: name,
                    enforceCanonicalHealthIntegers: membersAreHealthIntegers
                )
                if tracksPath { path.removeLast() }
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
            let tracksPath = numberLexemes != nil
            var element = 0
            while true {
                if tracksPath { path.append(.index(element)) }
                try parseValue(
                    depth: depth + 1,
                    memberName: nil,
                    enforceCanonicalHealthIntegers: false
                )
                if tracksPath { path.removeLast() }
                element += 1
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
        let string: String
        do {
            string = try container.decode(String.self)
        } catch let stringError as DecodingError {
            // The deployed PI sends some quantities as decimal strings and
            // others (computed USD volumes) as JSON numbers. JSONDecoder
            // exposes a number only after converting it to Double or Decimal,
            // which cannot keep every digit, so a number is read from the
            // exact text of the response instead. Without that text (a plain
            // JSONDecoder) a numeric token still fails closed.
            guard
                case .typeMismatch = stringError,
                let lexemes = decoder.userInfo[PINumberLexemes.userInfoKey]
                    as? PINumberLexemes,
                let lexeme = lexemes.lexeme(at: decoder.codingPath)
            else {
                throw stringError
            }
            try self.init(Self.plainDecimal(fromJSONNumber: lexeme))
            return
        }
        try self.init(string)
    }

    /// Rewrites a JSON number (`-?int[.frac][e[+-]exp]`) as the plain decimal
    /// this type stores, digit for digit: `1.5e3` is `1500`, `1e-7` is
    /// `0.0000001`. Only the position of the decimal point changes.
    static func plainDecimal(fromJSONNumber lexeme: String) throws -> String {
        guard lexeme.utf8.count <= maximumWireBytes else {
            throw PIIndexerError.invalidQuantity
        }
        let pattern =
            #"^(-?)(0|[1-9][0-9]*)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$"#
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: lexeme,
                range: NSRange(lexeme.startIndex..., in: lexeme)
            )
        else {
            throw PIIndexerError.invalidQuantity
        }
        func group(_ index: Int) -> String {
            Range(match.range(at: index), in: lexeme).map {
                String(lexeme[$0])
            } ?? ""
        }
        let sign = group(1)
        let integer = group(2)
        let fraction = group(3)
        let exponentText = group(4)
        guard !exponentText.isEmpty else {
            return lexeme
        }
        // The JSON grammar puts no limit on the digits of an exponent, and
        // `Int("-9223372036854775808")` is `Int.min`, which has no absolute
        // value. So the size is bounded on the digits, before any
        // arithmetic: at most four significant ones.
        let exponentDigits = exponentText
            .drop { $0 == "+" || $0 == "-" }
            .drop { $0 == "0" }
        guard
            exponentDigits.count <= 4,
            let exponentSize = exponentDigits.isEmpty
                ? 0
                : Int(exponentDigits),
            exponentSize <= maximumWireBytes
        else {
            throw PIIndexerError.invalidQuantity
        }
        let exponent = exponentText.hasPrefix("-")
            ? -exponentSize
            : exponentSize
        let digits = integer + fraction
        let point = integer.count + exponent
        var whole: String
        var decimals: String
        if point <= 0 {
            whole = "0"
            decimals = String(repeating: "0", count: -point) + digits
        } else if point >= digits.count {
            whole = digits + String(
                repeating: "0",
                count: point - digits.count
            )
            decimals = ""
        } else {
            whole = String(digits.prefix(point))
            decimals = String(digits.dropFirst(point))
        }
        // `0.5e1` shifts to `05`; a plain decimal has no leading zeros.
        let significant = whole.drop { $0 == "0" }
        whole = significant.isEmpty ? "0" : String(significant)
        // Zeros the shift left at the end of the fraction carry no value.
        while decimals.last == "0" {
            decimals.removeLast()
        }
        let plain = sign + whole + (decimals.isEmpty ? "" : "." + decimals)
        guard plain.utf8.count <= maximumWireBytes else {
            throw PIIndexerError.invalidQuantity
        }
        return plain
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

/// The exact number lexemes of one PI response, read on first use. A
/// response whose quantities are all strings (the usual case) never pays for
/// the extra pass.
final class PINumberLexemes {
    static let userInfoKey = CodingUserInfoKey(
        rawValue: "jp.co.soramitsu.sora.pi.number-lexemes"
    )!

    private let data: Data
    private let lock = NSLock()
    private var lexemes: [[PIStrictJSONAdmission.PathStep]: String]?

    init(data: Data) {
        self.data = data
    }

    func lexeme(at codingPath: [CodingKey]) -> String? {
        let path = codingPath.map { key -> PIStrictJSONAdmission.PathStep in
            key.intValue.map { .index($0) } ?? .key(key.stringValue)
        }
        lock.lock()
        defer { lock.unlock() }
        if lexemes == nil {
            lexemes = (try? PIStrictJSONAdmission.numberLexemesByPath(
                in: data
            )) ?? [:]
        }
        if let lexeme = lexemes?[path] {
            return lexeme
        }
        // The key of a decoded dictionary reports an integer value when
        // its text is a number (`{"0": 1.5}`), which looks like an array
        // index. Look the path up again with such keys as member names.
        let memberPath = codingPath.map {
            key -> PIStrictJSONAdmission.PathStep in
            if let index = key.intValue, key.stringValue != String(index) {
                return .index(index)
            }
            return .key(key.stringValue)
        }
        return memberPath == path ? nil : lexemes?[memberPath]
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
        } else if
            let lexemes = decoder.userInfo[PINumberLexemes.userInfoKey]
                as? PINumberLexemes,
            let lexeme = lexemes.lexeme(at: decoder.codingPath),
            let plain = try? PIQuantity.plainDecimal(fromJSONNumber: lexeme)
        {
            // A fractional number, or an integer beyond 64 bits. PI sends
            // computed values (USD amounts) as strings in some fields and as
            // JSON numbers in others, and may change one into the other.
            // JSONDecoder would round such a number through Double, so it
            // is taken from the exact text of the response instead, as
            // `PIQuantity` does.
            self = .number(plain)
        } else {
            // Without the text of the response (a plain JSONDecoder) a
            // fractional or unbounded number cannot be read exactly, and is
            // refused rather than rounded.
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
            } else if (try? PIQuantity(value)) != nil {
                // JSONEncoder has no exact form for a fractional or
                // unbounded number either. It is written as its decimal
                // text, which every reader of these values treats like the
                // number: they are shown or compared as text, never
                // calculated with. The validated history cache therefore
                // reads it back as the same text.
                try container.encode(value)
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

struct PIGraphQLError: Equatable {
    let message: String
    let path: [PIJSONValue]?
    /// `extensions.code`, when PI sent one. It tells a query PI refused
    /// (`BAD_USER_INPUT`) from a failure on PI's side
    /// (`INTERNAL_SERVER_ERROR`); both arrive with HTTP 200.
    var code: String? = nil

    /// PI could not answer for a reason of its own: a database error, a
    /// timeout, too much load. The same query may succeed a moment later.
    var isServiceFailure: Bool {
        guard let code = code?.uppercased() else {
            return false
        }
        return [
            "INTERNAL_SERVER_ERROR",
            "SERVICE_UNAVAILABLE",
            "UNAVAILABLE",
            "TOO_MANY_REQUESTS",
            "RATE_LIMITED",
        ].contains(code) ||
            code.contains("TIMEOUT") ||
            code.contains("TIMED_OUT")
    }
}

extension PIGraphQLError: Decodable {
    private enum CodingKeys: String, CodingKey {
        case message
        case path
        case extensions
    }

    private enum ExtensionKeys: String, CodingKey {
        case code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        path = try container.decodeIfPresent(
            [PIJSONValue].self,
            forKey: .path
        )
        // Only a string code is used; anything else in `extensions` is
        // ignored and never makes the response undecodable.
        code = (try? container.nestedContainer(
            keyedBy: ExtensionKeys.self,
            forKey: .extensions
        )).flatMap { try? $0.decode(String.self, forKey: .code) }
    }
}

enum PIIndexerError: LocalizedError {
    case invalidResponse
    case requestTooLarge
    case responseTooLarge
    case httpStatus(Int)
    case graphQLErrors
    /// PI answered that it failed on its own side (GraphQL errors whose
    /// codes are all service failures). Unlike `graphQLErrors`, the query
    /// was not refused.
    case serviceFailure
    /// The answer is not a JSON document, so it did not come from PI's
    /// GraphQL service: the sign-in page of a Wi-Fi network, or a page of a
    /// proxy or firewall in between.
    case foreignResponse
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
        case .serviceFailure:
            return "PI reported a failure on its side."
        case .foreignResponse:
            return "The answer did not come from PI."
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

    /// Failures after which the last good validated value may be shown
    /// instead of nothing. They have one thing in common: PI gave no answer
    /// to the query. It is unreachable or overloaded, it failed on its own
    /// side, something between the phone and PI answered in its place, or
    /// PI could not give one consistent, fresh checkpoint even after the
    /// bounded retry.
    ///
    /// An answer from PI that the client cannot use (it does not decode,
    /// fails validation, or refuses the query) is never hidden by older
    /// data.
    var allowsOfflineFallback: Bool {
        switch self {
        case .staleCheckpoint, .serviceFailure, .foreignResponse:
            return true
        case let .httpStatus(code):
            switch code {
            case 200 ... 299:
                // 200 never reaches here; any other success status is an
                // answer the client does not know how to use.
                return false
            case 400, 422:
                // PI's GraphQL endpoint refusing the request as it is
                // formed (see `indicatesUnsupportedSchema`).
                return false
            default:
                // A redirect (never followed), 401, 403, 404 and the like
                // from a proxy, firewall or sign-in page, 408, 429 and
                // every 5xx: no working PI answered.
                return true
            }
        default:
            return false
        }
    }

    /// One request failed in a way that often does not repeat: PI or a
    /// gateway in front of it failed for a moment.
    var isWorthAnotherTry: Bool {
        switch self {
        case .serviceFailure:
            return true
        case let .httpStatus(code):
            return [500, 502, 503, 504].contains(code)
        default:
            return false
        }
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
    /// For a value taken from the last good snapshot: when that snapshot
    /// was saved. `nil` for a live read.
    var savedAt: Date? = nil
    /// PI's health record changed between this read's own preflight and
    /// postflight. A multi-page read then treats a changed count or a
    /// repeated row as "the indexer moved, read again", not as a broken
    /// response.
    var checkpointAdvanced = false

    /// The same read with another view of its value.
    func map<Other>(_ transform: (Value) -> Other) -> PIQualifiedRead<Other> {
        PIQualifiedRead<Other>(
            value: transform(value),
            qualification: qualification,
            savedAt: savedAt,
            checkpointAdvanced: checkpointAdvanced
        )
    }
}

struct PIMobileChainNode: Decodable, Equatable {
    let name: String
    let address: URL
}

/// The `mobileConfig` fields every deployed PI schema serves.
struct PIMobileConfigBase: Decodable, Equatable {
    let blockExplorerUrl: URL
    let substrateTypesUrl: URL?
    let nodes: [PIMobileChainNode]

    /// The PI cannot confirm any optional feature, so all stay off.
    var withEveryFeatureOff: PIMobileConfig {
        PIMobileConfig(
            blockExplorerUrl: blockExplorerUrl,
            substrateTypesUrl: substrateTypesUrl,
            nodes: nodes,
            nexusAvailable: false,
            nexusSendsAvailable: false,
            polkamarktVisible: false,
            polkamarktMutationsAvailable: false,
            tairaDefaultVisible: false
        )
    }
}

struct PIMobileConfig: Decodable, Equatable {
    let blockExplorerUrl: URL
    let substrateTypesUrl: URL?
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

/// The asset fields the wallet shows: the USD price, the pooled liquidity
/// behind the market cap, and the 24-hour price change. PI also publishes
/// supply, order-book liquidity, the weekly change and USD volumes; nothing
/// in the app reads them, so they are not requested.
struct PIAsset: Codable, Equatable {
    let id: String
    let priceUSD: PIQuantity?
    let liquidity: PIQuantity?
    let priceChangeDay: Double?

    init(
        id: String,
        priceUSD: PIQuantity?,
        liquidity: PIQuantity?,
        priceChangeDay: Double?
    ) {
        self.id = id
        self.priceUSD = priceUSD
        self.liquidity = liquidity
        self.priceChangeDay = priceChangeDay
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case priceUSD
        case liquidity
        case priceChangeDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        priceUSD = try container.decodeIfPresent(
            PIQuantity.self,
            forKey: .priceUSD
        )
        liquidity = try container.decodeIfPresent(
            PIQuantity.self,
            forKey: .liquidity
        )
        // A presentation-only percentage. PI sends a JSON number today; a
        // decimal string, the form its other decimals use, reads the same.
        do {
            priceChangeDay = try container.decodeIfPresent(
                Double.self,
                forKey: .priceChangeDay
            )
        } catch DecodingError.typeMismatch {
            let quantity = try container.decode(
                PIQuantity.self,
                forKey: .priceChangeDay
            )
            guard let value = quantity.finiteDoubleForRendering else {
                throw PIIndexerError.invalidQuantity
            }
            priceChangeDay = value
        }
    }
}

struct PIPoolXYK: Codable, Equatable, Identifiable {
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

struct PIReferrerReward: Codable, Equatable, Identifiable {
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
        /// Seconds the PI server's clock was ahead of this device's clock
        /// when the entry was saved (negative when behind). `health` carries
        /// server timestamps and `savedAt` is device time, so replay compares
        /// them through this offset. Absent in entries from older builds.
        let clockSkewSeconds: Int?
    }

    private let fileManager: FileManager
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = (try? fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fileManager.temporaryDirectory
            self.directory = base.appendingPathComponent(
                "PIIndexer",
                isDirectory: true
            )
        }
        try? fileManager.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }

    func save(
        _ data: Data,
        health: PIHealth?,
        key: String,
        clockSkewSeconds: Int? = nil
    ) {
        let destination = url(for: key)
        guard
            isUsableDirectory(),
            isSafeDestination(destination),
            data.count <= PIResponseCacheAdmission.maximumPayloadBytes,
            (try? PIResponseCacheAdmission.validatePayload(data)) != nil,
            let encoded = try? encoder.encode(
                Entry(
                    savedAt: Date(),
                    payload: data,
                    health: health,
                    clockSkewSeconds: clockSkewSeconds
                )
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

/// Which account roles a PI history read covers.
enum PIHistoryCoverage: String, Codable, Equatable {
    /// Operations the account signed, and transfers it sent or received.
    case allRoles
    /// Only operations the account signed. The deployed PI's public query
    /// plan requires an exact `address` match outside any OR and rejects the
    /// all-roles filter, so transfers that others sent to the account are not
    /// listed. Balances are read from the chain and are not affected.
    case signedByAccount
}

/// Remembers, for this app run, that PI rejected the all-roles history
/// filter, so later reads use the accepted shape directly instead of being
/// rejected first. The all-roles filter is tried again after a while, so an
/// upgraded indexer is picked up without an app update.
final class PIHistoryShapeMemory {
    static let shared = PIHistoryShapeMemory()
    static let retryInterval: TimeInterval = 30 * 60

    private let lock = NSLock()
    private var allRolesRejectedAt: Date?

    func preferredCoverage(now: Date = Date()) -> PIHistoryCoverage {
        lock.lock()
        defer { lock.unlock() }
        guard
            let rejectedAt = allRolesRejectedAt,
            now.timeIntervalSince(rejectedAt) < Self.retryInterval,
            now >= rejectedAt
        else {
            return .allRoles
        }
        return .signedByAccount
    }

    func rememberAllRolesRejected(now: Date = Date()) {
        lock.lock()
        allRolesRejectedAt = now
        lock.unlock()
    }

    func reset() {
        lock.lock()
        allRolesRejectedAt = nil
        lock.unlock()
    }
}

/// One history page and the account roles it covers.
struct PIHistoryPageRead {
    let read: PIQualifiedRead<PIConnection<PIHistoryElement>>
    let coverage: PIHistoryCoverage
}

final class PIIndexerClient {
    static let endpoint = URL(string: "https://pi.soramitsu.io/graphql")!
    static let soraMainnetGenesis =
        "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"

    /// The client behind the shared price and pool catalogs.
    static let shared = PIIndexerClient(session: catalogSession)

    /// One session for every production client, so a multi-page read reuses
    /// its connection instead of opening a new one per client.
    private static let productionSession = makeProductionSession(
        waitsForConnectivity: true
    )

    /// The session of the shared catalogs. With no connection a catalog
    /// read fails at once instead of waiting 30 s for one: the catalog
    /// store has the last good catalog to show and its own retry schedule,
    /// and screens must not sit behind a request that cannot start.
    static let catalogSession = makeProductionSession(
        waitsForConnectivity: false
    )

    private static func makeProductionSession(
        waitsForConnectivity: Bool
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = waitsForConnectivity
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(
            configuration: configuration,
            delegate: PIRedirectRejectingDelegate.shared,
            delegateQueue: nil
        )
    }

    #if DEBUG
    private static let debugTreatsProductionAsUnreachable =
        ProcessInfo.processInfo.environment[
            "SORA_DEBUG_PI_UNREACHABLE"
        ] == "1"
    #endif

    /// A read that hit `staleCheckpoint` is tried again this many times
    /// before the last good value is used.
    static let maximumStaleCheckpointRetries = 2
    static let staleCheckpointRetryDelay: TimeInterval = 0.4
    /// Catalog snapshots (assets, pools, referral rewards) older than this
    /// are not shown.
    static let lastGoodCatalogMaximumAge = TimeInterval(24 * 60 * 60)

    /// The device clock offset the most recent live response showed.
    private final class ClockSkew {
        private let lock = NSLock()
        private var value: Int?

        var seconds: Int? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func record(_ seconds: Int) {
            lock.lock()
            value = seconds
            lock.unlock()
        }
    }

    private let endpoint: URL
    private let session: URLSession
    private let historyShapeMemory: PIHistoryShapeMemory
    private let cache: PIResponseCache
    private let lastClockSkew = ClockSkew()
    private let retryPause: (TimeInterval) async throws -> Void
    private static let maximumRequestBytes = 256 * 1024
    static let maximumResponseBytes = 4 * 1024 * 1024
    static let maximumCursorBytes = 4_096
    static let maximumHistoryPages = 20
    private let maximumPageSize = 100

    init(
        endpoint: URL = PIIndexerClient.endpoint,
        session: URLSession? = nil,
        historyShapeMemory: PIHistoryShapeMemory = .shared,
        cacheDirectory: URL? = nil,
        retryPause: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.endpoint = endpoint
        self.historyShapeMemory = historyShapeMemory
        self.session = session ?? Self.productionSession
        self.retryPause = retryPause
        cache = PIResponseCache(directory: cacheDirectory)
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
            validateAtResponseTime: { payload, nowEpochSeconds in
                // Freshness is judged against the time PI's own `Date`
                // header reports, so a device clock that is somewhat wrong
                // does not make a healthy indexer look stale.
                try Self.validateHealth(
                    payload._health,
                    nowEpochSeconds: nowEpochSeconds
                )
            }
        )
        return result._health
    }

    /// The time to judge one response's freshness against, and how far the
    /// device clock is from it.
    struct ResponseClock: Equatable {
        let nowEpochSeconds: Int
        /// Server minus device, in seconds; 0 when the server time is not
        /// used.
        let deviceSkewSeconds: Int
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        formatter.isLenient = false
        return formatter
    }()

    /// Parses an HTTP `Date` header in the IMF-fixdate form every current
    /// server sends (`Sun, 11 Oct 2026 00:34:40 GMT`).
    static func httpDate(_ value: String?) -> Date? {
        guard let value, value.utf8.count == 29 else {
            return nil
        }
        return httpDateFormatter.date(from: value)
    }

    /// Uses the server's `Date` whenever the header is present and well
    /// formed, however far the device clock is from it; otherwise the
    /// device clock.
    ///
    /// PI's timestamps are compared with the time PI itself reports in the
    /// same response, over the same TLS connection. Whoever could forge that
    /// header could forge the timestamps next to it, so a limit on the
    /// distance to the device clock would add no safety. It would only keep
    /// prices and Activity from a phone whose date was set by hand.
    static func responseClock(
        dateHeader: String?,
        deviceNow: Date = Date()
    ) -> ResponseClock {
        let device = Int(
            deviceNow.timeIntervalSince1970.rounded(.towardZero)
        )
        guard
            let server = httpDate(dateHeader)?.timeIntervalSince1970
        else {
            return ResponseClock(
                nowEpochSeconds: device,
                deviceSkewSeconds: 0
            )
        }
        let now = Int(server.rounded(.towardZero))
        return ResponseClock(
            nowEpochSeconds: now,
            deviceSkewSeconds: now - device
        )
    }

    static func validateHealth(
        _ health: PIHealth,
        nowEpochSeconds: Int = Int(Date().timeIntervalSince1970)
    ) throws {
        // Who answered: these never change for the reviewed production
        // service, so a mismatch is another service and is never papered
        // over with older data.
        guard
            health.service == "polkaswap-indexer",
            health.serviceId == "pi.soramitsu.io",
            health.schemaVersion == 1,
            health.readOnly,
            health.ecosystem == "sora2",
            health.chainId == "sora:mainnet",
            health.network == "mainnet",
            health.publicBaseUrl == endpoint,
            health.publicBaseUrl?.absoluteString == endpoint.absoluteString
        else {
            throw PIIndexerError.invalidServiceIdentity
        }
        // Whether it is ready: the right service that is starting up,
        // restarting or reporting a problem has no usable checkpoint for
        // now. That is temporary, so it takes the bounded retry and the
        // last good value like any other missing checkpoint.
        guard
            health.ok,
            health.repositoryReady,
            health.workerAvailable,
            health.workerReady == true,
            health.workerReadinessReason == nil,
            health.workerLifecycle == "running",
            health.workerStartupComplete == true
        else {
            throw PIIndexerError.staleCheckpoint
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

    /// The checkpoint one response is attributed to, from the health records
    /// read before and after it.
    ///
    /// PI indexes a new block about every six seconds, and its finalized
    /// head moves in between, so the two records often differ. That is
    /// normal progress: the same indexer may only have moved forward, and
    /// the response is then attributed to the later checkpoint, which bounds
    /// every row it can contain. A checkpoint that went backwards, or another
    /// service, chain or block at the same height, means a different or
    /// rolled-back indexer answered, and is rejected. This is the rule the
    /// Android client applies (`requireSettledResponseCheckpoint`).
    ///
    /// Forward progress is bounded: a postflight more than
    /// `maximumCheckpointAdvancePerRequest` blocks after the preflight means
    /// the response was received long before the postflight was read (the
    /// app was suspended in between, for example). It is then not known to
    /// be current at the later checkpoint, and the read starts again.
    static func settledResponseCheckpoint(
        preflight: PIHealth,
        postflight: PIHealth
    ) throws -> PIHealth {
        if preflight == postflight {
            return preflight
        }
        guard
            isSameIndexerAtOrAfter(preflight, postflight),
            isWithinAdvance(
                maximumCheckpointAdvancePerRequest,
                from: preflight,
                to: postflight
            )
        else {
            throw PIIndexerError.staleCheckpoint
        }
        return postflight
    }

    /// One request and its two health reads take a few hundred milliseconds
    /// and at most the 20 s request timeout each; PI indexes a block every
    /// six seconds. Twenty blocks (two minutes) is far more than a healthy
    /// read needs and far less than a suspended app loses.
    static let maximumCheckpointAdvancePerRequest = 20
    /// The same for a whole multi-page read (five minutes of blocks).
    static let maximumCheckpointAdvancePerWalk = 50

    static func isWithinAdvance(
        _ maximum: Int,
        from before: PIHealth,
        to after: PIHealth
    ) -> Bool {
        guard
            let beforeHeight = before.finalizedCheckpoint,
            let afterHeight = after.finalizedCheckpoint
        else {
            return false
        }
        let (advance, overflow) =
            afterHeight.subtractingReportingOverflow(beforeHeight)
        return !overflow && advance <= maximum
    }

    /// Pages of one live read must all lie within
    /// `maximumCheckpointAdvancePerWalk` blocks of its first page, so a read
    /// that was interrupted for a long time is never completed with old
    /// pages and labelled with a new checkpoint.
    static func validateWalkAdvance(
        first: PIReadQualification,
        current: PIReadQualification
    ) throws {
        guard
            current.source != .live || isWithinAdvance(
                maximumCheckpointAdvancePerWalk,
                from: first.health,
                to: current.health
            )
        else {
            throw PIIndexerError.staleCheckpoint
        }
    }

    static func isSameIndexerAtOrAfter(
        _ before: PIHealth,
        _ after: PIHealth
    ) -> Bool {
        guard
            let beforeHeight = before.finalizedCheckpoint,
            let afterHeight = after.finalizedCheckpoint,
            before.service == after.service,
            before.serviceId == after.serviceId,
            before.publicBaseUrl == after.publicBaseUrl,
            before.schemaVersion == after.schemaVersion,
            before.ecosystem == after.ecosystem,
            before.network == after.network,
            before.chainId.caseInsensitiveCompare(after.chainId) ==
                .orderedSame,
            hashesMatch(before.genesisHash, after.genesisHash),
            afterHeight >= beforeHeight
        else {
            return false
        }
        // One finalized height has one block.
        return afterHeight > beforeHeight || hashesMatch(
            before.latestIndexedBlockHash,
            after.latestIndexedBlockHash
        )
    }

    private static func hashesMatch(_ first: String?, _ second: String?) -> Bool {
        switch (first, second) {
        case (nil, nil):
            return true
        case let (.some(first), .some(second)):
            return first.caseInsensitiveCompare(second) == .orderedSame
        default:
            return false
        }
    }

    /// Pages of one live read may come from successive checkpoints of the
    /// same indexer while it keeps indexing. Pages replayed from the offline
    /// cache must all carry one checkpoint, and live and cached pages are
    /// never combined, so a result is never stitched together from different
    /// sessions.
    static func validatePageCheckpoint(
        previous: PIReadQualification,
        current: PIReadQualification
    ) throws {
        guard
            previous.source == current.source,
            previous.health == current.health || (
                current.source == .live &&
                    isSameIndexerAtOrAfter(previous.health, current.health)
            )
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
            [
                asset.priceUSD,
                asset.liquidity,
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
        // PI publishes a reward in the token's smallest unit, a whole
        // number ("183330193640403131" is 0.18 XOR). The Friends screen
        // converts it from that unit, so any other form is refused here
        // as a handled error instead of reaching the conversion.
        guard values.allSatisfy({
            PIHistoryCheckpointValidator.isNonNegativeIntegerQuantity(
                $0.amount
            )
        }) else {
            throw PIIndexerError.invalidQuantity
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

    /// Reads `mobileConfig`. The deployed PI may run an older schema without
    /// the feature-flag fields; it rejects the full query (HTTP 200 with
    /// GraphQL errors, or HTTP 400). Then the base fields are read with a
    /// schema-compatible query and every optional feature stays off.
    func qualifiedMobileConfig(
        requireLive: Bool = false
    ) async throws -> PIQualifiedRead<PIMobileConfig> {
        do {
            return try await qualifiedFlaggedMobileConfig(
                requireLive: requireLive
            )
        } catch let error as PIIndexerError where
            Self.indicatesUnsupportedSchema(error)
        {
            return try await qualifiedBaseMobileConfig(
                requireLive: requireLive
            )
        }
    }

    static func indicatesUnsupportedSchema(_ error: PIIndexerError) -> Bool {
        switch error {
        case .graphQLErrors, .httpStatus(400):
            return true
        default:
            return false
        }
    }

    private func qualifiedBaseMobileConfig(
        requireLive: Bool
    ) async throws -> PIQualifiedRead<PIMobileConfig> {
        struct Payload: Decodable { let mobileConfig: PIMobileConfigBase }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileConfigBase",
            query: """
            query MobileConfigBase {
              mobileConfig {
                blockExplorerUrl substrateTypesUrl
                nodes { name address }
              }
            }
            """,
            cachePolicy: requireLive
                ? .none
                : .offline(maximumAge: TimeInterval(7 * 24 * 60 * 60)),
            validateResponse: { payload, _ in
                try Self.validateMobileConfig(
                    payload.mobileConfig.withEveryFeatureOff
                )
            }
        )
        return result.map(\.mobileConfig.withEveryFeatureOff)
    }

    private func qualifiedFlaggedMobileConfig(
        requireLive: Bool
    ) async throws -> PIQualifiedRead<PIMobileConfig> {
        struct Payload: Decodable { let mobileConfig: PIMobileConfig }
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileConfig",
            query: """
            query MobileConfig {
              mobileConfig {
                blockExplorerUrl substrateTypesUrl
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
        return result.map(\.mobileConfig)
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
        after: String?,
        walkStep: WalkStep? = nil
    ) async throws -> PIQualifiedRead<PIConnection<PIAsset>> {
        try validate(pageSize: first)
        try Self.validateCursor(after)
        struct Payload: Decodable { let assets: PIConnection<PIAsset> }
        // Only the fields the wallet shows. PI serves `volumeDayUSD` and
        // `volumeWeekUSD` as JSON numbers while its other quantities are
        // strings; nothing reads them, so they are not requested.
        let result: PIQualifiedRead<Payload> = try await executeQualified(
            operationName: "MobileAssets",
            query: """
            query MobileAssets($first: Int!, $after: Cursor) {
              assets(first: $first, after: $after, orderBy: [ID_ASC]) {
                nodes { id priceUSD liquidity priceChangeDay }
                pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
                totalCount
              }
            }
            """,
            variables: compact(["first": first, "after": after]),
            cachePolicy: walkStep == nil
                ? .offline(maximumAge: TimeInterval(24 * 60 * 60))
                : .none,
            walkStep: walkStep,
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
        return result.map(\.assets)
    }

    /// The asset and pool catalogs are read whole, and every price in the
    /// app depends on that read. Registering an asset on SORA needs no
    /// permission, so the catalog grows; its walk gets the most pages the
    /// pager allows (10,000 rows at 100 per page; 957 assets and 432 pools
    /// on 12 October 2026).
    static let maximumCatalogPages = 100

    func allAssets(
        pageSize: Int = 100,
        maximumPages: Int = maximumCatalogPages
    ) async throws -> [PIAsset] {
        try await qualifiedAllAssets(
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    /// Every asset PI knows. A `.live` qualification is the checkpoint of
    /// the last page; `.cache` means the live read failed and this is the
    /// last good catalog.
    func qualifiedAllAssets(
        pageSize: Int = 100,
        maximumPages: Int = maximumCatalogPages
    ) async throws -> PIQualifiedRead<[PIAsset]> {
        try await lastGoodCatalog(
            name: Self.assetsCatalogName,
            itemIdentity: { $0.id },
            validate: { values, _ in try Self.validateAssets(values) }
        ) {
            try await self.retryingStaleCheckpoint {
                try await self.collectCheckpointedPages(
                    pageSize: pageSize,
                    maximumPages: maximumPages,
                    itemIdentity: { $0.id }
                ) { after, previousCheckpoint in
                    try await self.assetsRead(
                        first: pageSize,
                        after: after,
                        walkStep: WalkStep(
                            previousCheckpoint: previousCheckpoint
                        )
                    )
                }
            }
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
        after: String?,
        walkStep: WalkStep? = nil
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
            cachePolicy: walkStep == nil
                ? .offline(maximumAge: TimeInterval(24 * 60 * 60))
                : .none,
            walkStep: walkStep,
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
        return result.map(\.poolXYKs)
    }

    func allPoolXYKs(
        pageSize: Int = 100,
        maximumPages: Int = maximumCatalogPages
    ) async throws -> [PIPoolXYK] {
        try await qualifiedAllPoolXYKs(
            pageSize: pageSize,
            maximumPages: maximumPages
        ).value
    }

    /// Every XYK pool PI knows; qualified like `qualifiedAllAssets`.
    func qualifiedAllPoolXYKs(
        pageSize: Int = 100,
        maximumPages: Int = maximumCatalogPages
    ) async throws -> PIQualifiedRead<[PIPoolXYK]> {
        try await lastGoodCatalog(
            name: Self.poolsCatalogName,
            itemIdentity: { $0.id },
            validate: { values, _ in try Self.validatePools(values) }
        ) {
            try await self.retryingStaleCheckpoint {
                try await self.collectCheckpointedPages(
                    pageSize: pageSize,
                    maximumPages: maximumPages,
                    itemIdentity: { $0.id }
                ) { after, previousCheckpoint in
                    try await self.poolXYKsRead(
                        first: pageSize,
                        after: after,
                        walkStep: WalkStep(
                            previousCheckpoint: previousCheckpoint
                        )
                    )
                }
            }
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

    /// The deployed PI's public query plan may not order referrer rewards by
    /// timestamp. Totals do not depend on order, so `allReferrerRewards`
    /// falls back to ID order.
    enum ReferrerRewardOrder: String {
        case newestFirst = "[TIMESTAMP_DESC, ID_DESC]"
        case identifier = "[ID_DESC]"
    }

    private func referrerRewardsRead(
        address: String,
        first: Int,
        after: String?,
        order: ReferrerRewardOrder = .newestFirst,
        walkStep: WalkStep? = nil
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
                orderBy: \(order.rawValue)
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
            cachePolicy: walkStep == nil
                ? .offline(maximumAge: TimeInterval(24 * 60 * 60))
                : .none,
            walkStep: walkStep,
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
        return result.map(\.referrerRewards)
    }

    func allReferrerRewards(
        address: String,
        pageSize: Int = 100,
        maximumPages: Int = 20
    ) async throws -> [PIReferrerReward] {
        let address = try validatedIdentifier(address)
        func collect(
            _ order: ReferrerRewardOrder
        ) async throws -> PIQualifiedRead<[PIReferrerReward]> {
            try await retryingStaleCheckpoint {
                try await self.collectCheckpointedPages(
                    pageSize: pageSize,
                    maximumPages: maximumPages,
                    itemIdentity: { $0.id }
                ) { after, previousCheckpoint in
                    try await self.referrerRewardsRead(
                        address: address,
                        first: pageSize,
                        after: after,
                        order: order,
                        walkStep: WalkStep(
                            previousCheckpoint: previousCheckpoint
                        )
                    )
                }
            }
        }
        return try await lastGoodCatalog(
            name: "MobileReferrerRewardsCatalog",
            scope: address,
            itemIdentity: { $0.id },
            validate: { values, qualification in
                try Self.validateReferrerRewards(
                    values,
                    account: address,
                    qualification: qualification
                )
            }
        ) {
            do {
                return try await collect(.newestFirst)
            } catch let error as PIIndexerError where
                Self.indicatesUnsupportedSchema(error)
            {
                // Cursors are tied to their ordering, so restart from the
                // first page instead of continuing the rejected walk.
                return try await collect(.identifier)
            }
        }.value
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
        try await qualifiedHistoryPageWithCoverage(
            address: address,
            first: first,
            page: page,
            maximumPages: maximumPages
        ).read
    }

    /// Like `qualifiedHistoryPage`, and reports which account roles the page
    /// covers. When the deployed PI rejects the all-roles filter (HTTP 200
    /// with GraphQL errors, or HTTP 400), the whole walk restarts from page
    /// one with the signer-only filter it accepts: cursors belong to the
    /// filter they were issued for.
    func qualifiedHistoryPageWithCoverage(
        address: String,
        first: Int,
        page: Int,
        maximumPages: Int = maximumHistoryPages
    ) async throws -> PIHistoryPageRead {
        let result = try await withHistoryCoverageFallback { coverage in
            try await self.retryingStaleCheckpoint {
                try await self.walkHistoryPage(
                    address: address,
                    first: first,
                    page: page,
                    maximumPages: maximumPages,
                    coverage: coverage
                )
            }
        }
        return PIHistoryPageRead(read: result.value, coverage: result.coverage)
    }

    private func withHistoryCoverageFallback<Value>(
        _ read: (PIHistoryCoverage) async throws -> Value
    ) async throws -> (value: Value, coverage: PIHistoryCoverage) {
        let preferred = historyShapeMemory.preferredCoverage()
        do {
            return (try await read(preferred), preferred)
        } catch let error as PIIndexerError where
            preferred == .allRoles && Self.indicatesUnsupportedSchema(error)
        {
            historyShapeMemory.rememberAllRolesRejected()
            return (try await read(.signedByAccount), .signedByAccount)
        }
    }

    private func walkHistoryPage(
        address: String,
        first: Int,
        page: Int,
        maximumPages: Int,
        coverage: PIHistoryCoverage
    ) async throws -> PIQualifiedRead<PIConnection<PIHistoryElement>> {
        try Self.validateHistoryPage(page, maximumPages: maximumPages)
        try validate(pageSize: first)

        var cursor: String?
        var seenCursors = Set<String>()
        var seenItemIdentities = Set<String>()
        var expectedTotalCount: Int?
        var expectedQualification: PIReadQualification?
        var firstQualification: PIReadQualification?
        var consumedCount = 0
        var checkpointMoved = false
        // A transaction indexed between two pages changes the count and
        // shifts the rows. After the checkpoint moved, that is a reason to
        // walk again, not a broken response.
        func inconsistent(_ error: PIIndexerError) -> PIIndexerError {
            checkpointMoved ? .staleCheckpoint : error
        }

        // As in `collectPagesCore`: a page lost on the way is asked for
        // again instead of ending the walk.
        var transientRetries = TransientRetries()
        for currentPage in 1 ... page {
            var loaded: PIQualifiedRead<PIConnection<PIHistoryElement>>?
            while loaded == nil {
                do {
                    loaded = try await historyRead(
                        address: address,
                        first: first,
                        after: cursor,
                        coverage: coverage,
                        walkStep: WalkStep(
                            previousCheckpoint: expectedQualification?.health
                        )
                    )
                } catch let error where transientRetries.shouldRetry(
                    after: error,
                    afterProgress: currentPage > 1
                ) {
                    try await retryPause(transientRetries.pause)
                }
            }
            guard let read = loaded else {
                throw PIIndexerError.invalidResponse
            }
            guard let qualification = read.qualification else {
                throw PIIndexerError.missingChainIdentityCapability
            }
            if read.checkpointAdvanced {
                // PI moved while this very page was being read, so the
                // page can already differ from the ones before it.
                checkpointMoved = true
            }
            if let previous = expectedQualification {
                // The walk may follow the indexer forward; it never mixes
                // sources, indexers or a checkpoint that went backwards.
                try Self.validatePageCheckpoint(
                    previous: previous,
                    current: qualification
                )
                if previous.health != qualification.health {
                    checkpointMoved = true
                }
            }
            if let firstQualification {
                try Self.validateWalkAdvance(
                    first: firstQualification,
                    current: qualification
                )
            } else {
                firstQualification = qualification
            }
            // The returned page is attributed to the latest checkpoint,
            // which bounds every row read so far.
            expectedQualification = qualification

            let connection = read.value
            guard
                expectedTotalCount.map({ $0 == connection.totalCount }) ?? true
            else {
                throw inconsistent(.invalidResponse)
            }
            expectedTotalCount = connection.totalCount

            let identities = connection.values.compactMap {
                PIHistoryCheckpointValidator.canonicalHistoryIdentifier($0.id)
            }
            guard identities.count == connection.values.count else {
                throw PIIndexerError.repeatedPage
            }
            guard
                identities.allSatisfy({
                    seenItemIdentities.insert($0).inserted
                })
            else {
                throw inconsistent(.repeatedPage)
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
                throw inconsistent(.invalidResponse)
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
                throw inconsistent(.repeatedCursor)
            }
            cursor = next
        }
        throw PIIndexerError.paginationLimit
    }

    private func historyRead(
        address: String,
        first: Int,
        after: String?,
        transactionHashes: [String]? = nil,
        coverage: PIHistoryCoverage = .allRoles,
        walkStep: WalkStep? = nil
    ) async throws -> PIQualifiedRead<PIConnection<PIHistoryElement>> {
        let address = try validatedIdentifier(address)
        try validate(pageSize: first)
        try Self.validateHistoryPagination(after: after)
        var filter: [String: Any?] = [
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
        ]
        switch coverage {
        case .allRoles:
            // Bind public timestamp-ordered history to every exact account
            // role PI indexes. Incoming transfers and synthetic bridge mints
            // may identify the wallet only through dataFrom/dataTo.
            filter["or"] = [
                ["address": ["equalTo": address]],
                ["dataFrom": ["equalTo": address]],
                ["dataTo": ["equalTo": address]],
            ]
        case .signedByAccount:
            // The shape the deployed public query plan accepts: exact
            // signer equality outside any OR, ordered by timestamp.
            filter["address"] = ["equalTo": address]
        }
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
                "filter": compact(filter)
            ]),
            // History has a separate account-bound cache that is persisted
            // only after canonical SORA RPC block-hash validation. Reusing a
            // raw GraphQL page here would lose that proof and could bind it to
            // a different concurrent health checkpoint.
            cachePolicy: .none,
            walkStep: walkStep,
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
                if coverage == .signedByAccount {
                    // The signer-only filter returns only rows this account
                    // signed.
                    guard payload.historyElements.values.allSatisfy({
                        $0.address == address
                    }) else {
                        throw PIIndexerError.invalidChainIdentity
                    }
                }
                try Self.validateResponseHeights(
                    payload.historyElements.values.map(\.blockHeight),
                    qualification: qualification
                )
            }
        )
        return result.map(\.historyElements)
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
        try await withHistoryCoverageFallback { coverage in
            try await self.retryingStaleCheckpoint {
                try await self.collectCheckpointedPages(
                    pageSize: pageSize,
                    maximumPages: maximumPages,
                    itemIdentity: {
                        PIHistoryCheckpointValidator
                            .canonicalHistoryIdentifier($0.id) ?? ""
                    }
                ) { after, previousCheckpoint in
                    try await self.historyRead(
                        address: address,
                        first: pageSize,
                        after: after,
                        coverage: coverage,
                        walkStep: WalkStep(
                            previousCheckpoint: previousCheckpoint
                        )
                    )
                }
            }
        }.value
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
        return result.map(\.markets)
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
        return result.map(\.marketSnapshots)
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
        return result.map(\.accountPositions)
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
        return result.map(\.accountTrades)
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
        return result.map(\.polkamarktSignals)
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
        validateAtResponseTime: ((Payload, Int) throws -> Void)? = nil,
        validateResponse: (Payload, PIReadQualification?) throws -> Void = { _, _ in }
    ) async throws -> Payload {
        try await executeQualified(
            operationName: operationName,
            query: query,
            variables: variables,
            cachePolicy: cachePolicy,
            validateAtResponseTime: validateAtResponseTime,
            validateResponse: validateResponse
        ).value
    }

    /// One page of a multi-page read. The walk as a whole is what
    /// `retryingStaleCheckpoint` runs again and what the catalog snapshot
    /// backs up, so its pages neither retry nor use the page cache on their
    /// own.
    private struct WalkStep {
        /// The live checkpoint the previous page was attributed to, read
        /// immediately before this page. It serves as this page's preflight,
        /// so a walk costs two requests per page instead of three.
        let previousCheckpoint: PIHealth?
    }

    /// - Parameters:
    ///   - walkStep: Set for a page of a multi-page read.
    ///   - validateAtResponseTime: Checks that depend on the current time,
    ///     given the time this response's own clock reports.
    private func executeQualified<Payload: Decodable>(
        operationName: String,
        query: String,
        variables: [String: Any] = [:],
        cachePolicy: CachePolicy,
        walkStep: WalkStep? = nil,
        validateAtResponseTime: ((Payload, Int) throws -> Void)? = nil,
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

        // Exactly one level retries: a health read is retried by the
        // operation it qualifies, and a page by its walk.
        let maximumRetries =
            operationName == "MobileHealth" || walkStep != nil
                ? 0
                : Self.maximumStaleCheckpointRetries
        var staleCheckpointRetries = 0
        var transientRetries = TransientRetries()
        while true {
            do {
                return try await liveQualifiedRead(
                    operationName: operationName,
                    body: body,
                    cacheKey: cacheKey,
                    cachePolicy: cachePolicy,
                    knownPreflight: walkStep?.previousCheckpoint,
                    validateAtResponseTime: validateAtResponseTime,
                    validateResponse: validateResponse
                )
            } catch PIIndexerError.staleCheckpoint where
                staleCheckpointRetries < maximumRetries
            {
                // PI answered, but not with one consistent, fresh
                // checkpoint. That usually clears within a block or two, so
                // wait briefly and read again before giving up.
                staleCheckpointRetries += 1
                try await retryPause(
                    Self.staleCheckpointRetryDelay *
                        Double(staleCheckpointRetries)
                )
            } catch let error where
                maximumRetries > 0 && transientRetries.shouldRetry(
                    after: error,
                    afterProgress: false
                )
            {
                // The request, or one of its two health reads, was lost on
                // the way or failed on PI's side for a moment. The same
                // level that retries a stale checkpoint tries once more.
                try await retryPause(transientRetries.pause)
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
                        validateAtResponseTime: validateAtResponseTime,
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
                        validateAtResponseTime: validateAtResponseTime,
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
    }

    private func liveQualifiedRead<Payload: Decodable>(
        operationName: String,
        body: Data,
        cacheKey: String,
        cachePolicy: CachePolicy,
        knownPreflight: PIHealth?,
        validateAtResponseTime: ((Payload, Int) throws -> Void)?,
        validateResponse: (Payload, PIReadQualification?) throws -> Void
    ) async throws -> PIQualifiedRead<Payload> {
        let preflightHealth: PIHealth?
        if operationName != "MobileHealth" {
            // A cached health record is not sufficient to authorize fresh
            // indexed data because its finalized checkpoint may be stale.
            // If the live preflight is unreachable, the outer operation
            // may still use its own bounded offline cache.
            if let knownPreflight {
                preflightHealth = knownPreflight
            } else {
                preflightHealth = try await health(requireLive: true)
            }
        } else {
            preflightHealth = nil
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

        #if DEBUG
        // Debug builds only: lets the "PI cannot be reached" screens be
        // looked at on a simulator (`SIMCTL_CHILD_SORA_DEBUG_PI_UNREACHABLE=1
        // xcrun simctl launch ...`). Not compiled into Release builds.
        if Self.debugTreatsProductionAsUnreachable,
           session === Self.productionSession ||
            session === Self.catalogSession {
            throw URLError(.notConnectedToInternet)
        }
        #endif
        let (bytes, response) = try await session.bytes(for: request)
        let http = try Self.validateHTTPResponse(
            response,
            endpoint: endpoint
        )
        let clock = Self.responseClock(
            dateHeader: http.value(forHTTPHeaderField: "Date")
        )
        lastClockSkew.record(clock.deviceSkewSeconds)
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
        try validateAtResponseTime?(payload, clock.nowEpochSeconds)
        var qualification: PIReadQualification?
        var checkpointAdvanced = false
        if let preflightHealth {
            // Attribute the response to the checkpoint PI reports after it.
            // The indexer may have moved forward since the preflight; it may
            // not have gone backwards or become another indexer. This is
            // deliberately per request; a 30-second health cache cannot
            // prove which checkpoint produced an individual page.
            let postflightHealth = try await health(requireLive: true)
            qualification = PIReadQualification(
                health: try Self.settledResponseCheckpoint(
                    preflight: preflightHealth,
                    postflight: postflightHealth
                ),
                source: .live
            )
            checkpointAdvanced = preflightHealth != postflightHealth
        }
        // A decoded response is not cache-eligible until all operation-
        // specific identity and checkpoint bounds have passed.
        try validateResponse(payload, qualification)
        if case .offline = cachePolicy {
            await cache.save(
                data,
                health: qualification?.health,
                key: cacheKey,
                clockSkewSeconds: clock.deviceSkewSeconds
            )
        }
        return PIQualifiedRead(
            value: payload,
            qualification: qualification,
            checkpointAdvanced: checkpointAdvanced
        )
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
            // PI's GraphQL service answers in JSON only. Anything else with
            // status 200 is the page of a Wi-Fi sign-in, proxy or firewall.
            throw PIIndexerError.foreignResponse
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
        validateAtResponseTime: ((Payload, Int) throws -> Void)? = nil,
        validateResponse: (Payload, PIReadQualification?) throws -> Void
    ) throws -> PIQualifiedRead<Payload> {
        let payload = try decode(Payload.self, data: entry.payload)
        guard operationName != "MobileHealth" else {
            try validateAtResponseTime?(
                payload,
                Int(Date().timeIntervalSince1970)
            )
            try validateResponse(payload, nil)
            return PIQualifiedRead(value: payload, qualification: nil)
        }
        let qualification = try Self.cachedQualification(of: entry)
        try validateResponse(payload, qualification)
        return PIQualifiedRead(
            value: payload,
            qualification: qualification
        )
    }

    /// The checkpoint a cached entry was qualified at, checked as it was
    /// when the entry was saved.
    private static func cachedQualification(
        of entry: PIResponseCache.Entry
    ) throws -> PIReadQualification {
        guard let health = entry.health else {
            // Payload-only entries from an older app cannot prove which PI
            // checkpoint produced them and are deliberately not reusable.
            throw PIIndexerError.missingChainIdentityCapability
        }
        // `health` holds server timestamps and `savedAt` is device time.
        let savedAt = entry.savedAt.timeIntervalSince1970 +
            Double(entry.clockSkewSeconds ?? 0)
        guard
            savedAt.isFinite,
            savedAt >= 0,
            savedAt <= Double(Int.max)
        else {
            throw PIIndexerError.invalidResponse
        }
        try validateHealth(
            health,
            nowEpochSeconds: Int(savedAt.rounded(.towardZero))
        )
        return PIReadQualification(health: health, source: .cache)
    }

    /// Transport failures: no answer from PI arrived at all. The last good
    /// validated value may be shown in its place, marked with its time.
    ///
    /// That includes a TLS failure. On a network that intercepts TLS (a
    /// Wi-Fi sign-in page, a filtering proxy) nothing is read from the
    /// other side, and showing what PI itself said earlier gives that
    /// network nothing it could not get by dropping the connection.
    /// A cancelled request and a request that could not be formed are not
    /// transport failures.
    static func allowsOfflineTransportFallback(_ error: URLError) -> Bool {
        switch error.code {
        case
            // No route, no connection, or the connection broke.
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
            .resourceUnavailable,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed,
            .cannotLoadFromNetwork,
            // TLS could not be established with PI.
            .secureConnectionFailed,
            .serverCertificateUntrusted,
            .serverCertificateHasBadDate,
            .serverCertificateNotYetValid,
            .serverCertificateHasUnknownRoot,
            .clientCertificateRejected,
            .clientCertificateRequired,
            // The network wants a sign-in before it lets anything through.
            .userAuthenticationRequired,
            // What arrived is not an HTTP response the system can read.
            .badServerResponse,
            .cannotParseResponse,
            .cannotDecodeContentData,
            .cannotDecodeRawData,
            .zeroByteResource,
            .httpTooManyRedirects,
            .redirectToNonExistentLocation:
            return true
        default:
            return false
        }
    }

    /// One request failed in a way that often does not repeat: the
    /// connection dropped or stalled, PI or a gateway failed for a moment.
    /// With no network at all there is nothing to try again; the catalog
    /// store and the screens have their own schedule for that.
    static func isWorthAnotherTry(_ error: Error) -> Bool {
        if let error = error as? PIIndexerError {
            return error.isWorthAnotherTry
        }
        guard let error = error as? URLError else {
            return false
        }
        switch error.code {
        case
            .timedOut,
            .networkConnectionLost,
            .secureConnectionFailed,
            .badServerResponse,
            .cannotParseResponse:
            return true
        default:
            return false
        }
    }

    /// How many more tries one logical read (a single request with its
    /// health reads, or a whole multi-page read) gets for failures that are
    /// worth another try.
    static let maximumTransientRetries = 2
    static let transientRetryDelay: TimeInterval = 0.5

    /// Counts the tries of one logical read and waits before the next one.
    /// Returns `false` when the error is not worth another try or the read
    /// has had its share.
    private struct TransientRetries {
        private var used = 0

        /// - Parameter afterProgress: PI answered earlier in this same
        ///   read. A timeout is tried again only then, and only once: it
        ///   has already cost the whole request timeout (20 to 30 s), and
        ///   with nothing read yet it usually means there is no connection,
        ///   where waiting twice would only delay the saved copy.
        mutating func shouldRetry(
            after error: Error,
            afterProgress: Bool
        ) -> Bool {
            guard
                used < PIIndexerClient.maximumTransientRetries,
                PIIndexerClient.isWorthAnotherTry(error)
            else {
                return false
            }
            if (error as? URLError)?.code == .timedOut {
                guard afterProgress else {
                    return false
                }
                used = PIIndexerClient.maximumTransientRetries
            } else {
                used += 1
            }
            return true
        }

        var pause: TimeInterval {
            PIIndexerClient.transientRetryDelay * Double(max(1, used))
        }
    }

    private func decode<Payload: Decodable>(
        _ type: Payload.Type,
        data: Data
    ) throws -> Payload {
        try Self.decodeResponse(type, from: data)
    }

    /// Admits and decodes one GraphQL response document. Every live and
    /// cached PI response goes through here.
    static func decodeResponse<Payload: Decodable>(
        _ type: Payload.Type,
        from data: Data
    ) throws -> Payload {
        try PIStrictJSONAdmission.validate(data)
        let decoder = JSONDecoder()
        // Lets `PIQuantity` read a quantity PI sent as a JSON number from
        // its exact text.
        decoder.userInfo[PINumberLexemes.userInfoKey] =
            PINumberLexemes(data: data)
        let envelope = try decoder.decode(
            PIGraphQLResponse<Payload>.self,
            from: data
        )
        if let errors = envelope.errors, !errors.isEmpty {
            // Do not retain the raw GraphQL text in the thrown error: debug
            // descriptions are frequently logged by generic infrastructure.
            // PI reports a failure of its own (a database error, a timeout)
            // the same way as a query it refuses: HTTP 200 with `errors`.
            // Only when every error says "service failure" is it one.
            throw errors.allSatisfy(\.isServiceFailure)
                ? PIIndexerError.serviceFailure
                : PIIndexerError.graphQLErrors
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
        ) { cursor, _ in
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
            itemIdentity: itemIdentity
        ) { cursor, _ in
            try await loader(cursor)
        }
    }

    /// Like `collectQualifiedPagesRead`; the loader also receives the live
    /// checkpoint the previous page was attributed to, which it may pass on
    /// as that page's successor's preflight.
    private func collectCheckpointedPages<Node: Decodable & Equatable>(
        pageSize: Int,
        maximumPages: Int,
        itemIdentity: ((Node) -> String)? = nil,
        loader: @escaping (String?, PIHealth?) async throws ->
            PIQualifiedRead<PIConnection<Node>>
    ) async throws -> PIQualifiedRead<[Node]> {
        try await collectPagesCore(
            pageSize: pageSize,
            maximumPages: maximumPages,
            requireQualification: true,
            itemIdentity: itemIdentity,
            retriesLostPages: true,
            loader: loader
        )
    }

    /// Runs one logical read again from its start when PI could not serve it
    /// from one consistent run of checkpoints, a bounded number of times.
    private func retryingStaleCheckpoint<Value>(
        _ read: () async throws -> Value
    ) async throws -> Value {
        var retries = 0
        while true {
            do {
                return try await read()
            } catch PIIndexerError.staleCheckpoint where
                retries < Self.maximumStaleCheckpointRetries
            {
                retries += 1
                try await retryPause(
                    Self.staleCheckpointRetryDelay * Double(retries)
                )
            }
        }
    }

    private func collectPagesCore<Node: Decodable & Equatable>(
        pageSize: Int,
        maximumPages: Int,
        requireQualification: Bool,
        itemIdentity: ((Node) -> String)? = nil,
        retriesLostPages: Bool = false,
        loader: @escaping (String?, PIHealth?) async throws ->
            PIQualifiedRead<PIConnection<Node>>
    ) async throws -> PIQualifiedRead<[Node]> {
        guard (1 ... 100).contains(maximumPages) else {
            throw PIIndexerError.paginationLimit
        }
        try validate(pageSize: pageSize)
        // A walk is up to 201 requests in a row. One of them lost on the
        // way must not throw away every page already read: that page alone
        // is asked for again, a bounded number of times per walk. The
        // checkpoint rules apply to the page that then arrives like to any
        // other. Only for pages that do not retry on their own.
        var transientRetries = TransientRetries()

        var result: [Node] = []
        var cursor: String?
        var seenCursors = Set<String>()
        var seenPages: [[Node]] = []
        var seenItemIdentities = Set<String>()
        var expectedTotalCount: Int?
        var expectedQualification: PIReadQualification?
        var firstQualification: PIReadQualification?
        var checkpointMoved = false
        // While PI keeps indexing, a row can be added, removed or moved
        // between two pages, which shows up as a changed count or a repeated
        // row or page. With an unchanged checkpoint that is a broken
        // response; after the checkpoint moved it only means the read has to
        // start again.
        func inconsistent(_ error: PIIndexerError) -> PIIndexerError {
            checkpointMoved ? .staleCheckpoint : error
        }
        for _ in 0 ..< maximumPages {
            let previousLiveHealth =
                expectedQualification?.source == .live
                    ? expectedQualification?.health
                    : nil
            var loaded: PIQualifiedRead<PIConnection<Node>>?
            while loaded == nil {
                do {
                    loaded = try await loader(cursor, previousLiveHealth)
                } catch let error where
                    retriesLostPages &&
                    transientRetries.shouldRetry(
                        after: error,
                        afterProgress: !result.isEmpty
                    )
                {
                    try await retryPause(transientRetries.pause)
                }
            }
            guard let read = loaded else {
                throw PIIndexerError.invalidResponse
            }
            if read.checkpointAdvanced {
                // PI moved while this very page was being read, so the
                // page can already differ from the ones before it.
                checkpointMoved = true
            }
            if requireQualification {
                guard let qualification = read.qualification else {
                    throw PIIndexerError.missingChainIdentityCapability
                }
                if let firstQualification {
                    try Self.validateWalkAdvance(
                        first: firstQualification,
                        current: qualification
                    )
                } else {
                    firstQualification = qualification
                }
                if let previous = expectedQualification {
                    // Never compose one logical result from cached and live
                    // pages, from another indexer, or from a checkpoint that
                    // went backwards. Forward progress is accepted.
                    try Self.validatePageCheckpoint(
                        previous: previous,
                        current: qualification
                    )
                    if previous.health != qualification.health {
                        checkpointMoved = true
                    }
                }
                expectedQualification = qualification
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
                Self.isBoundedCursor(page.pageInfo.endCursor)
            else {
                throw PIIndexerError.invalidResponse
            }
            guard
                expectedTotalCount.map({ $0 == page.totalCount }) ?? true
            else {
                throw inconsistent(.invalidResponse)
            }
            expectedTotalCount = page.totalCount
            if !values.isEmpty {
                guard !seenPages.contains(values) else {
                    throw inconsistent(.repeatedPage)
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
                        $0.utf8.count <= 4_096
                }) else {
                    throw PIIndexerError.invalidResponse
                }
                guard identities.allSatisfy({
                    seenItemIdentities.insert($0).inserted
                }) else {
                    throw inconsistent(.invalidResponse)
                }
            }
            let (nextCount, countOverflow) = result.count
                .addingReportingOverflow(values.count)
            guard !countOverflow, nextCount <= page.totalCount else {
                throw inconsistent(.invalidResponse)
            }
            result.append(contentsOf: values)
            guard page.pageInfo.hasNextPage else {
                guard result.count == page.totalCount else {
                    throw inconsistent(.invalidResponse)
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
                throw inconsistent(.repeatedCursor)
            }
            cursor = next
        }
        throw PIIndexerError.paginationLimit
    }

    // MARK: - Last good catalogs

    /// A whole catalog as it was last read live, stored as one PI-shaped
    /// document so it is admitted, decoded and validated like a response.
    private struct CatalogSnapshot<Node: Codable>: Codable {
        struct Catalog: Codable {
            let nodes: [Node]
            let totalCount: Int
        }

        let catalog: Catalog
    }

    private struct CatalogSnapshotDocument<Node: Codable>: Encodable {
        let data: CatalogSnapshot<Node>
    }

    static func allowsLastGoodValue(_ error: Error) -> Bool {
        if let error = error as? PIIndexerError {
            return error.allowsOfflineFallback
        }
        if let error = error as? URLError {
            return allowsOfflineTransportFallback(error)
        }
        return false
    }

    /// Reads a complete catalog live and remembers it. When the live read
    /// fails because PI is unreachable, overloaded or without a consistent
    /// fresh checkpoint, the last good catalog (at most
    /// `lastGoodCatalogMaximumAge` old) is returned with a `.cache`
    /// qualification instead of an error.
    private func lastGoodCatalog<Node: Codable & Equatable>(
        name: String,
        scope: String = "",
        itemIdentity: @escaping (Node) -> String,
        validate: @escaping ([Node], PIReadQualification) throws -> Void,
        live: () async throws -> PIQualifiedRead<[Node]>
    ) async throws -> PIQualifiedRead<[Node]> {
        let key = catalogKey(name: name, scope: scope)
        let liveError: Error
        do {
            let read = try await live()
            if
                let qualification = read.qualification,
                qualification.source == .live,
                let document = try? JSONEncoder().encode(
                    CatalogSnapshotDocument(
                        data: CatalogSnapshot(
                            catalog: .init(
                                nodes: read.value,
                                totalCount: read.value.count
                            )
                        )
                    )
                )
            {
                await cache.save(
                    document,
                    health: qualification.health,
                    key: key,
                    clockSkewSeconds: lastClockSkew.seconds
                )
            }
            return read
        } catch {
            guard Self.allowsLastGoodValue(error) else {
                throw error
            }
            liveError = error
        }

        guard let saved = await savedCatalog(
            name: name,
            scope: scope,
            itemIdentity: itemIdentity,
            validate: validate
        ) else {
            throw liveError
        }
        return saved
    }

    private func catalogKey(name: String, scope: String) -> String {
        var identity = Data(endpoint.absoluteString.utf8)
        identity.append(0)
        identity.append(Data(scope.utf8))
        let digest = Data(SHA256.hash(data: identity))
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(name)-\(digest)"
    }

    /// The last good catalog as an earlier live read saved it, without any
    /// request: `.cache` qualified, with the time it was saved. `nil` when
    /// there is none, when it is older than `lastGoodCatalogMaximumAge`, or
    /// when it no longer passes the checks a response has to pass (it is
    /// then removed).
    private func savedCatalog<Node: Codable & Equatable>(
        name: String,
        scope: String = "",
        itemIdentity: @escaping (Node) -> String,
        validate: @escaping ([Node], PIReadQualification) throws -> Void
    ) async -> PIQualifiedRead<[Node]>? {
        let key = catalogKey(name: name, scope: scope)
        guard let entry = await cache.load(
            key: key,
            maximumAge: Self.lastGoodCatalogMaximumAge
        ) else {
            return nil
        }
        do {
            let snapshot = try decode(
                CatalogSnapshot<Node>.self,
                data: entry.payload
            ).catalog
            let qualification = try Self.cachedQualification(of: entry)
            let identities = snapshot.nodes.map(itemIdentity)
            guard
                snapshot.totalCount == snapshot.nodes.count,
                identities.allSatisfy({ !$0.isEmpty }),
                Set(identities).count == identities.count
            else {
                throw PIIndexerError.invalidResponse
            }
            try validate(snapshot.nodes, qualification)
            return PIQualifiedRead(
                value: snapshot.nodes,
                qualification: qualification,
                savedAt: entry.savedAt
            )
        } catch {
            await cache.remove(key: key)
            return nil
        }
    }

    /// The asset catalog the last successful `qualifiedAllAssets` saved, for
    /// showing prices marked with their time while this run's first read is
    /// on its way. No request is made.
    func savedAllAssets() async -> PIQualifiedRead<[PIAsset]>? {
        await savedCatalog(
            name: Self.assetsCatalogName,
            itemIdentity: { $0.id },
            validate: { values, _ in try Self.validateAssets(values) }
        )
    }

    /// The pool catalog the last successful `qualifiedAllPoolXYKs` saved.
    /// No request is made.
    func savedAllPoolXYKs() async -> PIQualifiedRead<[PIPoolXYK]>? {
        await savedCatalog(
            name: Self.poolsCatalogName,
            itemIdentity: { $0.id },
            validate: { values, _ in try Self.validatePools(values) }
        )
    }

    private static let assetsCatalogName = "MobileAssetsCatalog"
    private static let poolsCatalogName = "MobilePoolXYKsCatalog"

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

/// A catalog as a screen may show it.
struct PICatalogSnapshot<Node> {
    let values: [Node]
    /// `nil` when the catalog is current. Otherwise the time it dates from:
    /// PI could not be read since, and the screen should say so.
    let asOf: Date?
}

/// One shared reader for a PI catalog that many screens ask for at once.
///
/// - A live catalog is reused for `freshFor` without any request.
/// - After that a refresh starts, once for all callers. A caller is never
///   kept waiting when there is anything to show: the catalog this run
///   holds, or the one an earlier run saved (`saved`, looked at once), is
///   returned at once and replaced when the refresh ends (`onChange` tells
///   the screens). It carries its time (`asOf`) unless it is live, younger
///   than `staleFor` and PI answered the last time it was asked. Only a
///   caller with nothing at all to show waits for the refresh.
/// - After a failed read the next one waits (`retryDelays`, growing with each
///   failure in a row). Until then callers get the last good catalog, marked
///   with its time, or the error when there is none, without any request.
/// - The last good catalog is used for at most `lastGoodFor` after it was
///   read from PI. It is shown while a read is on its way and after the
///   failures the client itself accepts as "PI cannot be read right now"
///   (`allowsLastGood`). Once PI has answered with a response that does not
///   decode or fails validation, older data is no longer shown in its
///   place, until a read succeeds or fails in the accepted way.
///
/// All ages are measured on a clock that keeps counting while the device
/// sleeps, so a catalog loaded before the phone was locked is old when the
/// phone is unlocked hours later.
actor PICatalogStore<Node> {
    typealias Loader = () async throws -> PIQualifiedRead<[Node]>
    /// The catalog an earlier run saved, read without any request.
    typealias SavedLoader = () async -> PIQualifiedRead<[Node]>?

    static var defaultRetryDelays: [TimeInterval] { [15, 30, 60, 120, 300] }

    /// Seconds on a clock that never goes backwards and, unlike
    /// `ProcessInfo.systemUptime`, also counts the time the device sleeps.
    static func continuousUptime() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) /
            1_000_000_000
    }

    private struct Held {
        let values: [Node]
        /// On `uptime`. For a snapshot from disk this is the time it was
        /// read from PI, not the time it was loaded from disk.
        let loadedAt: TimeInterval
        /// The same moment on the wall clock, for display only.
        let date: Date
        let isLive: Bool
    }

    private struct Flight {
        let id: UUID
        let task: Task<PIQualifiedRead<[Node]>, Error>
    }

    private let freshFor: TimeInterval
    private let staleFor: TimeInterval
    private let lastGoodFor: TimeInterval
    private let retryDelays: [TimeInterval]
    private let uptime: () -> TimeInterval
    private let wallClock: () -> Date
    private let allowsLastGood: (Error) -> Bool
    private let onChange: (() -> Void)?
    private let saved: SavedLoader?
    private let load: Loader

    private var held: Held?
    private var failuresInARow = 0
    private var nextAttemptAt: TimeInterval = 0
    /// The most recent read that finished did not give a live catalog.
    private var lastReadFailed = false
    private var lastError: Error?
    private var flight: Flight?
    private var savedRead: Task<Void, Never>?
    private var savedWasRead = false

    /// - Parameters:
    ///   - staleFor: How old a live catalog may be and still be shown
    ///     without its time while its refresh is running. Never less than
    ///     `freshFor`.
    ///   - uptime: A clock that never goes backwards and counts sleep.
    ///     Wall-clock time is not used for ages, so changing the device
    ///     clock neither forces nor blocks a refresh.
    ///   - onChange: Called after every finished read, successful or not:
    ///     what `snapshot()` returns may have changed.
    ///   - saved: The catalog an earlier run saved, with the time it was
    ///     saved. Asked once, when the first caller finds nothing held.
    init(
        freshFor: TimeInterval,
        staleFor: TimeInterval? = nil,
        lastGoodFor: TimeInterval = PIIndexerClient.lastGoodCatalogMaximumAge,
        retryDelays: [TimeInterval] = PICatalogStore.defaultRetryDelays,
        uptime: @escaping () -> TimeInterval = {
            PICatalogStore.continuousUptime()
        },
        wallClock: @escaping () -> Date = { Date() },
        allowsLastGood: @escaping (Error) -> Bool = {
            PIIndexerClient.allowsLastGoodValue($0)
        },
        onChange: (() -> Void)? = nil,
        saved: SavedLoader? = nil,
        load: @escaping Loader
    ) {
        self.freshFor = freshFor
        self.staleFor = max(freshFor, staleFor ?? freshFor)
        self.lastGoodFor = lastGoodFor
        self.retryDelays = retryDelays.isEmpty ? [60] : retryDelays
        self.uptime = uptime
        self.wallClock = wallClock
        self.allowsLastGood = allowsLastGood
        self.onChange = onChange
        self.saved = saved
        self.load = load
    }

    /// The catalog: fresh when it can be read, otherwise the last good one.
    /// Throws only when there is nothing to show.
    func values() async throws -> [Node] {
        try await snapshot().values
    }

    func snapshot() async throws -> PICatalogSnapshot<Node> {
        if let fresh = fresh(at: uptime()) {
            return fresh
        }
        // Ask PI before looking at the disk, so that the request does not
        // wait for the file.
        if flight == nil, uptime() >= nextAttemptAt {
            startFlight()
        }
        await readSavedOnce()

        let now = uptime()
        if let fresh = fresh(at: now) {
            // The read ended while the saved catalog was looked at.
            return fresh
        }
        if let shown = presentable(at: now) {
            // Something can be shown: the caller does not wait. The read
            // that is running, or the next one after the backoff, replaces
            // it and announces itself.
            return shown
        }
        guard let current = flight else {
            // Nothing to show and the next read is not due yet: no request.
            throw lastError ?? PIIndexerError.staleCheckpoint
        }

        do {
            let read = try await current.task.value
            if read.qualification?.source != .cache {
                return PICatalogSnapshot(values: read.value, asOf: nil)
            }
            // PI could not be read and the client fell back to the
            // snapshot on disk. What this run holds is at least as new.
            if let shown = presentable(at: uptime()) {
                return shown
            }
            return PICatalogSnapshot(
                values: read.value,
                asOf: read.savedAt ?? wallClock()
            )
        } catch {
            if let shown = presentable(at: uptime()) {
                return shown
            }
            throw error
        }
    }

    /// The app is in front again: whatever made PI unreadable before (no
    /// network in the background, a locked device) may be over, so the next
    /// caller starts a read at once instead of sitting out a backoff that
    /// was earned hours ago. What the last read said about PI still stands
    /// until that read ends: the catalog held keeps its time, and callers
    /// still do not wait for the read.
    func clearBackoff() {
        failuresInARow = 0
        nextAttemptAt = 0
    }

    /// Returns when no read is running. For tests.
    func settled() async {
        while let flight {
            _ = try? await flight.task.value
        }
    }

    private func fresh(at now: TimeInterval) -> PICatalogSnapshot<Node>? {
        guard let held, held.isLive, now - held.loadedAt < freshFor else {
            return nil
        }
        return PICatalogSnapshot(values: held.values, asOf: nil)
    }

    /// Once per run: the catalog an earlier run saved becomes the one held
    /// when this run has none yet. Callers that arrive while the file is
    /// read wait for the same read.
    private func readSavedOnce() async {
        guard let saved, !savedWasRead else { return }
        if savedRead == nil {
            savedRead = Task { [weak self] in
                let read = await saved()
                await self?.adopt(saved: read)
            }
        }
        await savedRead?.value
    }

    private func adopt(saved read: PIQualifiedRead<[Node]>?) {
        savedWasRead = true
        savedRead = nil
        guard held == nil, let read else { return }
        let date = read.savedAt ?? wallClock()
        let age = max(0, wallClock().timeIntervalSince(date))
        held = Held(
            values: read.value,
            loadedAt: uptime() - age,
            date: date,
            isLive: false
        )
    }

    @discardableResult
    private func startFlight() -> Flight {
        let id = UUID()
        let load = self.load
        let task = Task { [weak self] () throws -> PIQualifiedRead<[Node]> in
            // The result is recorded here, not by whoever is waiting, so a
            // refresh nobody waits for still replaces the catalog.
            do {
                let read = try await load()
                await self?.finish(id, read: read)
                return read
            } catch {
                await self?.finish(id, error: error)
                throw error
            }
        }
        let started = Flight(id: id, task: task)
        flight = started
        return started
    }

    private func finish(_ id: UUID, read: PIQualifiedRead<[Node]>) {
        guard flight?.id == id else { return }
        flight = nil
        let now = uptime()
        if read.qualification?.source == .cache {
            // PI could not be read live and the client fell back to its
            // last good snapshot. Show it under its real age, and keep
            // trying on the failure schedule.
            if lastGood(at: now) == nil {
                let date = read.savedAt ?? wallClock()
                let age = max(0, wallClock().timeIntervalSince(date))
                held = Held(
                    values: read.value,
                    loadedAt: now - age,
                    date: date,
                    isLive: false
                )
            }
            lastError = nil
            lastReadFailed = true
            scheduleRetry(from: now)
        } else {
            held = Held(
                values: read.value,
                loadedAt: now,
                date: wallClock(),
                isLive: true
            )
            failuresInARow = 0
            nextAttemptAt = 0
            lastError = nil
            lastReadFailed = false
        }
        onChange?()
    }

    private func finish(_ id: UUID, error: Error) {
        guard flight?.id == id else { return }
        flight = nil
        lastError = error
        lastReadFailed = true
        scheduleRetry(from: uptime())
        onChange?()
    }

    private func scheduleRetry(from now: TimeInterval) {
        let delay = retryDelays[min(failuresInARow, retryDelays.count - 1)]
        failuresInARow += 1
        nextAttemptAt = now + delay
    }

    private func lastGood(at now: TimeInterval) -> Held? {
        guard let held, now - held.loadedAt < lastGoodFor else {
            return nil
        }
        return held
    }

    /// What may be shown without waiting for PI. Nothing when PI's latest
    /// answer could not be used (older data must not stand in for it) or
    /// when the catalog held is older than `lastGoodFor`. Otherwise the
    /// catalog held, marked with its time unless it is live, younger than
    /// `staleFor`, and PI answered the last time it was asked.
    private func presentable(
        at now: TimeInterval
    ) -> PICatalogSnapshot<Node>? {
        if let lastError, !allowsLastGood(lastError) {
            return nil
        }
        guard let held = lastGood(at: now) else {
            return nil
        }
        let isCurrent = held.isLive && !lastReadFailed &&
            now - held.loadedAt < staleFor
        return PICatalogSnapshot(
            values: held.values,
            asOf: isCurrent ? nil : held.date
        )
    }
}

/// The catalogs behind fiat prices, market data and pool APY.
enum PICatalogs {
    /// Posted (on no particular queue) when prices may have changed: a read
    /// of the asset catalog has finished, or the app has come back to the
    /// foreground. Screens that show prices ask for them again.
    static let pricesDidChange = Notification.Name(
        "jp.co.soramitsu.sora.PICatalogs.pricesDidChange"
    )

    /// Prices and market data change slowly on screen; ten minutes matches
    /// what the fiat and market-cap services cached before. While a refresh
    /// is running the catalog held is shown: as it is up to thirty minutes,
    /// with its time after that.
    static let assets: PICatalogStore<PIAsset> = {
        _ = foregroundObserver
        return PICatalogStore<PIAsset>(
            freshFor: 600,
            staleFor: 1_800,
            onChange: {
                NotificationCenter.default.post(
                    name: pricesDidChange,
                    object: nil
                )
            },
            saved: {
                await PIIndexerClient.shared.savedAllAssets()
            },
            load: {
                try await PIIndexerClient.shared.qualifiedAllAssets()
            }
        )
    }()

    static let pools: PICatalogStore<PIPoolXYK> = {
        _ = foregroundObserver
        return PICatalogStore<PIPoolXYK>(
            freshFor: 60,
            staleFor: 600,
            saved: {
                await PIIndexerClient.shared.savedAllPoolXYKs()
            },
            load: {
                try await PIIndexerClient.shared.qualifiedAllPoolXYKs()
            }
        )
    }()

    private static let foregroundObserver: NSObjectProtocol =
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                await assets.clearBackoff()
                await pools.clearBackoff()
                NotificationCenter.default.post(
                    name: pricesDidChange,
                    object: nil
                )
            }
        }
}
