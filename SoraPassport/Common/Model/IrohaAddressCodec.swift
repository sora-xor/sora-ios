// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

enum IrohaNetworkKind: String, Codable, Equatable {
    case taira
    case minamoto
    case development
    case custom
}

enum IrohaAddressErrorCode: String, Equatable {
    case invalidLength
    case checksumMismatch
    case invalidHexAddress
    case missingI105Sentinel
    case i105TooShort
    case invalidI105Base
    case invalidI105Char
    case invalidI105Digit
    case unsupportedAddressFormat
    case unexpectedNetworkPrefix
    case invalidI105Prefix
    case invalidHeaderVersion
    case invalidNormVersion
    case unknownAddressClass
    case unexpectedExtensionFlag
    case unknownControllerTag
    case unknownCurve
    case unexpectedTrailingBytes
}

struct IrohaAddressError: Error, Equatable {
    let code: IrohaAddressErrorCode
}

struct IrohaAddressDetails: Equatable {
    let chainDiscriminant: Int
    let network: IrohaNetworkKind
    let canonicalHex: String
    let publicKeyHex: String
    let i105: String
}

/// I105 codec for the canonical single-key Ed25519 account representation.
///
/// Parsing is deliberately strict: an address must round-trip to the exact
/// supplied string and callers can require the selected network discriminant.
enum IrohaAddressCodec {
    static let tairaDiscriminant = 369
    static let minamotoDiscriminant = 753

    private static let devDiscriminant = 0
    private static let discriminantMaximum = 0x3FFF
    private static let checksumLength = 6
    private static let base = 105
    private static let maximumAddressCharacters = 160
    private static let maximumAddressBytes = 512
    private static let bech32mConstant: UInt32 = 0x2BC8_30A3
    private static let checksumHrp = "snx"
    private static let controllerSingleKeyTag: UInt8 = 0
    private static let curveEd25519: UInt8 = 1
    private static let ed25519PublicKeyLength = 32
    private static let base58Alphabet = Array(
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    )
    private static let poemAlphabet: [Character] = [
        "\u{ff72}", "\u{ff9b}", "\u{ff8a}", "\u{ff86}", "\u{ff8e}", "\u{ff8d}",
        "\u{ff84}", "\u{ff81}", "\u{ff98}", "\u{ff87}", "\u{ff99}", "\u{ff66}",
        "\u{ff9c}", "\u{ff76}", "\u{ff96}", "\u{ff80}", "\u{ff9a}", "\u{ff7f}",
        "\u{ff82}", "\u{ff88}", "\u{ff85}", "\u{ff97}", "\u{ff91}", "\u{ff73}",
        "\u{30f0}", "\u{ff89}", "\u{ff75}", "\u{ff78}", "\u{ff94}", "\u{ff8f}",
        "\u{ff79}", "\u{ff8c}", "\u{ff7a}", "\u{ff74}", "\u{ff83}", "\u{ff71}",
        "\u{ff7b}", "\u{ff77}", "\u{ff95}", "\u{ff92}", "\u{ff90}", "\u{ff7c}",
        "\u{30f1}", "\u{ff8b}", "\u{ff93}", "\u{ff7e}", "\u{ff7d}"
    ]
    private static let bech32Generators: [UInt32] = [
        0x3B6A_57B2, 0x2650_8E6D, 0x1EA1_19FA, 0x3D42_33DD, 0x2A14_62B3
    ]

    private static var alphabet: [Character] {
        base58Alphabet + poemAlphabet
    }

    private static var digitTable: [Character: Int] {
        Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) })
    }

    static func canonicalHex(publicKeyHex: String) throws -> String {
        try publicKeyToCanonicalBytes(publicKeyHex: publicKeyHex).hexString()
    }

    static func encode(publicKeyHex: String, chainDiscriminant: Int) throws -> String {
        try encodeCanonicalHex(
            canonicalHex(publicKeyHex: publicKeyHex),
            chainDiscriminant: chainDiscriminant
        )
    }

    static func encodeCanonicalHex(_ canonicalHex: String, chainDiscriminant: Int) throws -> String {
        try encodeLiteral(
            chainDiscriminant: resolveDiscriminant(chainDiscriminant),
            canonicalBytes: normalizeHexBytes(canonicalHex)
        )
    }

    static func parse(_ address: String, expectedDiscriminant: Int? = nil) throws -> IrohaAddressDetails {
        guard
            !address.isEmpty,
            address.count <= maximumAddressCharacters,
            address.utf8.count <= maximumAddressBytes,
            address.trimmingCharacters(in: .whitespacesAndNewlines) == address,
            !address.hasPrefix("0x"),
            !address.hasPrefix("0X")
        else {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }

        let decoded = try decodeLiteral(address)
        if let expected = try expectedDiscriminant.map(resolveDiscriminant),
           decoded.chainDiscriminant != expected {
            throw IrohaAddressError(code: .unexpectedNetworkPrefix)
        }

        let publicKeyHex = try decodeCanonicalSingleEd25519(decoded.canonicalBytes)
        let canonicalAddress = try encodeLiteral(
            chainDiscriminant: decoded.chainDiscriminant,
            canonicalBytes: decoded.canonicalBytes
        )
        guard canonicalAddress == address else {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }

        return IrohaAddressDetails(
            chainDiscriminant: decoded.chainDiscriminant,
            network: network(for: decoded.chainDiscriminant),
            canonicalHex: decoded.canonicalBytes.hexString(),
            publicKeyHex: publicKeyHex,
            i105: canonicalAddress
        )
    }

    static func isValid(_ address: String, expectedDiscriminant: Int? = nil) -> Bool {
        (try? parse(address, expectedDiscriminant: expectedDiscriminant)) != nil
    }

    private static func resolveDiscriminant(_ value: Int) throws -> Int {
        guard (0 ... discriminantMaximum).contains(value) else {
            throw IrohaAddressError(code: .invalidI105Prefix)
        }
        return value
    }

    private static func network(for discriminant: Int) -> IrohaNetworkKind {
        switch discriminant {
        case minamotoDiscriminant:
            return .minamoto
        case tairaDiscriminant:
            return .taira
        case devDiscriminant:
            return .development
        default:
            return .custom
        }
    }

    private static func sentinel(for discriminant: Int) -> String {
        switch discriminant {
        case minamotoDiscriminant:
            return "sora"
        case tairaDiscriminant:
            return "test"
        case devDiscriminant:
            return "dev"
        default:
            return "n\(discriminant)"
        }
    }

    private static func discriminant(from input: String) -> Int? {
        if input.hasPrefix("sora") {
            return minamotoDiscriminant
        }
        if input.hasPrefix("test") {
            return tairaDiscriminant
        }
        if input.hasPrefix("dev") {
            return devDiscriminant
        }
        guard input.hasPrefix("n") else {
            return nil
        }

        let digits = input.dropFirst().prefix(5).prefix { character in
            character.unicodeScalars.count == 1 &&
                character.unicodeScalars.first.map { (48 ... 57).contains(Int($0.value)) } == true
        }
        guard
            !digits.isEmpty,
            let value = Int(String(digits)),
            value <= discriminantMaximum
        else {
            return nil
        }
        return value
    }

    private static func encodeLiteral(
        chainDiscriminant: Int,
        canonicalBytes: [UInt8]
    ) throws -> String {
        let payload = try encodeBaseN(bytes: canonicalBytes, base: base)
        let checksum = checksumDigits(canonicalBytes)
        let symbols = try (payload + checksum).map { String(try digitSymbol($0)) }
        return ([sentinel(for: chainDiscriminant)] + symbols).joined()
    }

    private static func decodeLiteral(
        _ input: String
    ) throws -> (chainDiscriminant: Int, canonicalBytes: [UInt8]) {
        guard let value = discriminant(from: input) else {
            throw IrohaAddressError(code: .missingI105Sentinel)
        }
        let prefix = sentinel(for: value)
        guard input.hasPrefix(prefix) else {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }
        return (value, try decodePayload(String(input.dropFirst(prefix.count))))
    }

    private static func decodePayload(_ payload: String) throws -> [UInt8] {
        let table = digitTable
        let digits = try payload.map { character in
            guard let digit = table[character] else {
                throw IrohaAddressError(code: .invalidI105Char)
            }
            return digit
        }
        guard digits.count > checksumLength else {
            throw IrohaAddressError(code: .i105TooShort)
        }

        let splitIndex = digits.count - checksumLength
        let canonicalBytes = try decodeBaseN(
            digits: Array(digits[..<splitIndex]),
            base: base
        )
        guard Array(digits[splitIndex...]) == checksumDigits(canonicalBytes) else {
            throw IrohaAddressError(code: .checksumMismatch)
        }
        return canonicalBytes
    }

    private static func digitSymbol(_ digit: Int) throws -> Character {
        guard alphabet.indices.contains(digit) else {
            throw IrohaAddressError(code: .invalidI105Digit)
        }
        return alphabet[digit]
    }

    private static func encodeBaseN(bytes: [UInt8], base: Int) throws -> [Int] {
        guard base >= 2 else {
            throw IrohaAddressError(code: .invalidI105Base)
        }
        guard !bytes.isEmpty else {
            return [0]
        }

        var value = bytes.map(Int.init)
        let leadingZeros = value.prefix { $0 == 0 }.count
        var digits: [Int] = []
        var start = leadingZeros
        while start < value.count {
            var remainder = 0
            for index in start ..< value.count {
                let accumulator = (remainder << 8) | value[index]
                value[index] = accumulator / base
                remainder = accumulator % base
            }
            digits.append(remainder)
            while start < value.count, value[start] == 0 {
                start += 1
            }
        }
        digits.append(contentsOf: Array(repeating: 0, count: leadingZeros))
        return Array((digits.isEmpty ? [0] : digits).reversed())
    }

    private static func decodeBaseN(digits: [Int], base: Int) throws -> [UInt8] {
        guard base >= 2 else {
            throw IrohaAddressError(code: .invalidI105Base)
        }
        guard !digits.isEmpty else {
            throw IrohaAddressError(code: .invalidLength)
        }

        var value = digits
        let leadingZeros = value.prefix { $0 == 0 }.count
        var bytes: [Int] = []
        var start = leadingZeros
        while start < value.count {
            var remainder = 0
            for index in start ..< value.count {
                guard value[index] < base else {
                    throw IrohaAddressError(code: .invalidI105Digit)
                }
                let accumulator = remainder * base + value[index]
                value[index] = accumulator / 256
                remainder = accumulator % 256
            }
            bytes.append(remainder)
            while start < value.count, value[start] == 0 {
                start += 1
            }
        }
        bytes.append(contentsOf: Array(repeating: 0, count: leadingZeros))
        return bytes.reversed().map(UInt8.init)
    }

    private static func checksumDigits(_ bytes: [UInt8]) -> [Int] {
        let values = expandHrp(checksumHrp) +
            convertToBase32(bytes) +
            Array(repeating: 0, count: checksumLength)
        let value = polymod(values) ^ bech32mConstant
        return (0 ..< checksumLength).map { index in
            Int((value >> UInt32(5 * (checksumLength - 1 - index))) & 0x1F)
        }
    }

    private static func convertToBase32(_ bytes: [UInt8]) -> [Int] {
        var accumulator = 0
        var bitCount = 0
        var result: [Int] = []
        for byte in bytes {
            accumulator = ((accumulator << 8) | Int(byte)) & 0xFFF
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append((accumulator >> bitCount) & 0x1F)
            }
        }
        if bitCount > 0 {
            result.append((accumulator << (5 - bitCount)) & 0x1F)
        }
        return result
    }

    private static func polymod(_ values: [Int]) -> UInt32 {
        var checksum: UInt32 = 1
        for value in values {
            let top = checksum >> 25
            checksum = ((checksum & 0x1FFFFFF) << 5) ^ UInt32(value)
            for (index, generator) in bech32Generators.enumerated()
                where ((top >> UInt32(index)) & 1) == 1 {
                checksum ^= generator
            }
        }
        return checksum
    }

    private static func expandHrp(_ hrp: String) -> [Int] {
        hrp.utf8.map { Int($0 >> 5) } + [0] + hrp.utf8.map { Int($0 & 31) }
    }

    private static func decodeCanonicalSingleEd25519(_ bytes: [UInt8]) throws -> String {
        guard let header = bytes.first else {
            throw IrohaAddressError(code: .invalidLength)
        }
        if header & 1 == 1 {
            throw IrohaAddressError(code: .unexpectedExtensionFlag)
        }
        if header >> 5 != 0 {
            throw IrohaAddressError(code: .invalidHeaderVersion)
        }
        if (header >> 1) & 0b11 != 1 {
            throw IrohaAddressError(code: .invalidNormVersion)
        }
        if (header >> 3) & 0b11 != 0 {
            throw IrohaAddressError(code: .unknownAddressClass)
        }
        guard bytes.count >= 4 else {
            throw IrohaAddressError(code: .invalidLength)
        }
        guard bytes[1] == controllerSingleKeyTag else {
            throw IrohaAddressError(code: .unknownControllerTag)
        }
        guard bytes[2] == curveEd25519 else {
            throw IrohaAddressError(code: .unknownCurve)
        }
        let length = Int(bytes[3])
        guard length == ed25519PublicKeyLength, bytes.count >= 4 + length else {
            throw IrohaAddressError(code: .invalidLength)
        }
        guard bytes.count == 4 + length else {
            throw IrohaAddressError(code: .unexpectedTrailingBytes)
        }
        return String(Array(bytes[4 ..< (4 + length)]).hexString().dropFirst(2))
    }

    private static func publicKeyToCanonicalBytes(publicKeyHex: String) throws -> [UInt8] {
        let key = try normalizeHexBytes(publicKeyHex, expectedBytes: ed25519PublicKeyLength)
        return [0x02, controllerSingleKeyTag, curveEd25519, UInt8(key.count)] + key
    }

    private static func normalizeHexBytes(
        _ value: String,
        expectedBytes: Int? = nil
    ) throws -> [UInt8] {
        let hex = value.hasPrefix("0x") || value.hasPrefix("0X")
            ? String(value.dropFirst(2))
            : value
        guard
            !hex.isEmpty,
            hex.count % 2 == 0,
            hex.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil
        else {
            throw IrohaAddressError(code: .invalidHexAddress)
        }
        if let expectedBytes, hex.count != expectedBytes * 2 {
            throw IrohaAddressError(code: .invalidLength)
        }

        var result: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(String(hex[index ..< next]), radix: 16) else {
                throw IrohaAddressError(code: .invalidHexAddress)
            }
            result.append(byte)
            index = next
        }
        return result
    }
}

private extension Array where Element == UInt8 {
    func hexString() -> String {
        "0x" + map { String(format: "%02x", $0) }.joined()
    }
}
