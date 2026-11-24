import Foundation

enum ScryptParametersError: Error {
    case invalidDataLength
    case invalidSalt
}

public struct ScryptParameters {
    public static let saltLength = 32
    public static let encodedLength = 44
    public static let saltRange = 0 ..< Self.saltLength
    public static let scryptNRange = Self.saltLength ..< (Self.saltLength + 4)
    public static let scryptPRange = (Self.saltLength + 4) ..< (Self.saltLength + 8)
    public static let scryptRRange = (Self.saltLength + 8) ..< (Self.saltLength + 12)

    public let salt: Data
    public let scryptN: UInt32
    public let scryptP: UInt32
    public let scryptR: UInt32

    public init(salt: Data, scryptN: UInt32, scryptP: UInt32, scryptR: UInt32) throws {
        guard salt.count == Self.saltLength else {
            throw ScryptParametersError.invalidSalt
        }

        self.salt = salt
        self.scryptN = scryptN
        self.scryptP = scryptP
        self.scryptR = scryptR
    }

    public init(scryptN: UInt32 = 32768, scryptP: UInt32 = 1, scryptR: UInt32 = 8) throws {
        let data = try Data.generateRandomBytes(of: Self.saltLength)
        try self.init(salt: data, scryptN: scryptN, scryptP: scryptP, scryptR: scryptR)
    }

    public init(data: Data) throws {
        guard data.count >= Self.encodedLength else {
            throw ScryptParametersError.invalidDataLength
        }

        salt = Data(data[Self.saltRange])

        let valueN: UInt32 = data[Self.scryptNRange].withUnsafeBytes { $0.pointee }
        scryptN = valueN.littleEndian

        let valueP: UInt32 = data[Self.scryptPRange].withUnsafeBytes { $0.pointee }
        scryptP = valueP.littleEndian

        let valueR: UInt32 = data[Self.scryptRRange].withUnsafeBytes { $0.pointee }
        scryptR = valueR.littleEndian
    }

    public func encode() -> Data {
        var data = Data(repeating: 0, count: Self.encodedLength)
        data.replaceSubrange(Self.saltRange, with: salt)

        var scryptN = self.scryptN
        data.replaceSubrange(
            Self.scryptNRange,
            with: Data(bytes: &scryptN, count: MemoryLayout<UInt32>.size)
        )

        var scryptP = self.scryptP
        data.replaceSubrange(
            Self.scryptPRange,
            with: Data(bytes: &scryptP, count: MemoryLayout<UInt32>.size)
        )

        var scryptR = self.scryptR
        data.replaceSubrange(
            Self.scryptRRange,
            with: Data(bytes: &scryptR, count: MemoryLayout<UInt32>.size)
        )

        return data
    }
}

// MARK: - Encrypted payload bounds

public extension ScryptParameters {
    /// The largest scrypt + XSalsa20-Poly1305 payload (header, nonce, box) accepted.
    static let maximumEncryptedLength = 1_048_576
    static let macLength = 16
    /// The header, the nonce and the MAC of an empty message.
    static let minimumEncryptedLength =
        encodedLength + KeystoreConstants.nonceLength + macLength

    /// Reads the header of an encrypted payload only if its nonce and MAC are
    /// present and its key derivation work is bounded, so callers can check
    /// it before any native scrypt work or slicing. These are the limits of
    /// the SORA app's Google Drive recovery path; the backup and keystore
    /// writers (SORA, Fearless, Polkadot.js) use N=32768, r=8, p=1.
    init?(boundedEncryptedData data: Data) {
        guard data.count >= Self.minimumEncryptedLength,
              data.count <= Self.maximumEncryptedLength,
              let parameters = try? Self(data: data) else
        {
            return nil
        }

        let n = UInt64(parameters.scryptN)
        let r = UInt64(parameters.scryptR)
        let p = UInt64(parameters.scryptP)
        // Each bound is checked before the products, so they cannot overflow.
        guard n >= 2, n.nonzeroBitCount == 1, n <= 262_144,
              r > 0, r <= 32, p > 0, p <= 16,
              n * r <= 2_097_152, n * r * p <= 4_194_304 else
        {
            return nil
        }

        self = parameters
    }
}
