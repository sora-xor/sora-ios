import CryptoKit
import Foundation

/// Current fixed-V1 Norito encoding for a single Ed25519 asset transfer.
/// This module never receives private keys. The app signs `signingMessage` locally.
public enum NexusTransferCodec {
    public enum Error: Swift.Error { case invalidNetwork, invalidKey, invalidAsset, invalidQuantity, invalidLifetime, invalidSignature, invalidMetadata }

    public struct FeeLimit {
        public let kind: UInt32
        public let assetDefinition: String
        public let maximum: String
        public init(kind: UInt32, assetDefinition: String, maximum: String) {
            self.kind = kind; self.assetDefinition = assetDefinition; self.maximum = maximum
        }
    }

    public static func payload(
        network: Data, authorityKey: Data, recipientKey: Data, assetDefinition: String,
        amount: String, creationTimeMs: UInt64, ttlMs: UInt64 = 100_000,
        nonce: UInt32? = nil, fees: [FeeLimit] = [], metadata: [String: String] = [:]
    ) throws -> Data {
        guard network.count == 32, network.last! & 1 == 1 else { throw Error.invalidNetwork }
        guard creationTimeMs > 0, ttlMs > 0, ttlMs <= 100_000, nonce != 0,
              creationTimeMs <= UInt64.max - ttlMs else { throw Error.invalidLifetime }
        let authority = try account(authorityKey)
        let source = field(authority) + field(try asset(assetDefinition)) + field(u32(0))
        let transfer = field(source) + field(try quantity(amount, allowZero: false)) + field(try account(recipientKey))
        let frame = framedTransfer(u32(2) + field(transfer))
        let wireName = Data("iroha.transfer".utf8)
        let instruction = field(field(wireName)) + field(u64(UInt64(frame.count)) + frame)
        let executable = u32(0) + field(u64(1) + field(instruction))
        let limits = try fees.enumerated().map { index, fee -> Data in
            guard fee.kind <= 1, index == 0 || fees[index - 1].kind < fee.kind else { throw Error.invalidQuantity }
            return field(field(u32(fee.kind)) + field(try asset(fee.assetDefinition)) + field(try quantity(fee.maximum, allowZero: true)))
        }.reduce(Data(), +)
        let feePayment = u32(0) + field(field(u64(UInt64(fees.count)) + limits) + field(Data([0])))
        var meta = u64(UInt64(metadata.count))
        for name in metadata.keys.sorted(by: { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }) {
            guard !name.isEmpty, name.utf8.count <= 255,
                  name.utf8.allSatisfy({ (33...126).contains($0) && ![35, 36, 64].contains($0) }) else { throw Error.invalidMetadata }
            let value = try JSONEncoder().encode(metadata[name]!)
            meta += field(field(field(Data(name.utf8))) + field(field(field(value))))
        }
        return field(u32(0) + field(network)) + field(authority) + field(u64(creationTimeMs)) + field(executable)
            + field(Data([1]) + field(u64(ttlMs)))
            + field(nonce.map { Data([1]) + field(u32($0)) } ?? Data([0]))
            + field(feePayment) + field(meta) + field(Data([0]))
    }

    public static func signingMessage(_ payload: Data) -> Data { hash(payload) }
    public static func transactionHash(_ payload: Data) -> Data { hash(u32(0) + field(payload)) }

    public static func envelope(payload: Data, signature: Data, publicKey: Data) throws -> Data {
        guard !payload.isEmpty, signature.count == 64, publicKey.count == 32,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey),
              key.isValidSignature(signature, for: signingMessage(payload)) else { throw Error.invalidSignature }
        let signatureBytes = u64(UInt64(signature.count)) + byteFields(signature)
        return Data([1]) + field(field(signatureBytes)) + field(payload) + field(Data([0]))
    }

    /// Dynamic instruction payload used in Torii's exact unsigned fee quote.
    public static func transferFrame(authorityKey: Data, recipientKey: Data, assetDefinition: String, amount: String) throws -> Data {
        let source = field(try account(authorityKey)) + field(try asset(assetDefinition)) + field(u32(0))
        return framedTransfer(u32(2) + field(field(source) + field(try quantity(amount, allowZero: false)) + field(try account(recipientKey))))
    }

    /// JSON InstructionBox is base64 of the framed (wire name, framed payload) pair.
    public static func instructionJSON(authorityKey: Data, recipientKey: Data, assetDefinition: String, amount: String) throws -> String {
        let transfer = try transferFrame(authorityKey: authorityKey, recipientKey: recipientKey, assetDefinition: assetDefinition, amount: amount)
        let body = field(field(Data("iroha.transfer".utf8))) + field(u64(UInt64(transfer.count)) + transfer)
        let schema = Data([0x86,0x2a,0x7d,0x77,0x07,0x5d,0x4d,0x23,0xff,0x6c,0x12,0x61,0xdb,0x02,0x78,0x11])
        return frame(body, schema: schema).base64EncodedString()
    }

    public static func canonicalQuantity(_ raw: String, allowZero: Bool = false) throws -> String {
        guard raw.utf8.count <= 164, raw.range(of: #"^(0|[1-9][0-9]*)(\.[0-9]{1,9})?$"#, options: .regularExpression) != nil else { throw Error.invalidQuantity }
        var value = raw
        if value.contains(".") {
            while value.last == "0" { value.removeLast() }
            if value.last == "." { value.removeLast() }
        }
        guard allowZero || value != "0" else { throw Error.invalidQuantity }
        return value
    }

    static func account(_ publicKey: Data) throws -> Data {
        guard publicKey.count == 32, publicKey.contains(where: { $0 != 0 }) else { throw Error.invalidKey }
        return u32(0) + field(u64(33) + byteFields(Data([0]) + publicKey))
    }

    static func asset(_ literal: String) throws -> Data {
        guard let uuid = AssetDefinitionAddress.decode(literal) else { throw Error.invalidAsset }
        return byteFields(uuid)
    }

    static func quantity(_ raw: String, allowZero: Bool) throws -> Data {
        let value = try canonicalQuantity(raw, allowZero: allowZero)
        let parts = value.split(separator: ".")
        let scale = parts.count == 2 ? parts[1].count : 0
        var magnitude: [UInt8] = [0]
        for digit in value.utf8 where digit != 46 {
            var carry = Int(digit - 48)
            for index in magnitude.indices {
                carry += Int(magnitude[index]) * 10
                magnitude[index] = UInt8(carry & 255); carry >>= 8
            }
            if carry != 0 { magnitude.append(UInt8(carry)) }
            guard magnitude.count <= 64 else { throw Error.invalidQuantity }
        }
        // Signed-512 BigInt uses minimal little-endian two's-complement bytes.
        if magnitude.last! & 0x80 != 0 { magnitude.append(0) }
        guard magnitude.count <= 64 else { throw Error.invalidQuantity }
        return field(u32(UInt32(magnitude.count)) + Data(magnitude)) + field(u32(UInt32(scale)))
    }

    private static func framedTransfer(_ body: Data) -> Data {
        // Rust TransferBox schema identity; validated against SDK and live Torii fixtures.
        let schema = Data([0xa4,0x17,0x4c,0x78,0xd6,0x34,0x1f,0x8f,0x98,0xfc,0x2a,0xda,0xe8,0xed,0x67,0xb9])
        return frame(body, schema: schema)
    }

    static func frame(_ body: Data, schema: Data) -> Data {
        return Data("NRT0".utf8) + Data([0,0]) + schema + Data([0]) + u64(UInt64(body.count)) + u64(crc64(body)) + Data([2]) + body
    }

    private static func hash(_ bytes: Data) -> Data {
        var digest = Blake2b.hash256(bytes); digest[digest.count - 1] |= 1; return digest
    }
    private static func byteFields(_ bytes: Data) -> Data { Data(bytes.flatMap { [UInt8(1), $0] }) }
    static func field(_ bytes: Data) -> Data {
        var length = bytes.count, prefix = Data()
        while length >= 128 { prefix.append(UInt8(length & 127) | 128); length >>= 7 }
        prefix.append(UInt8(length)); return prefix + bytes
    }
    static func u32(_ value: UInt32) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
    static func u64(_ value: UInt64) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
    private static func crc64(_ data: Data) -> UInt64 {
        var crc = UInt64.max
        for byte in data {
            crc ^= UInt64(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xc96c5795d7870f42 : crc >> 1 }
        }
        return ~crc
    }
}
