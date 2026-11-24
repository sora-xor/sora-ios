import IrohaCrypto
import SSFModels
import SSFUtils
import TweetNacl
import XCTest

@testable import SSFCloudStorage

final class EncryptionServiceTests: XCTestCase {
    func testCreateEncryptedData() throws {
        // arrange
        let service = EncryptionService()

        // act
        let encodedPath = try service.createEncryptedData(
            with: "1",
            message: TestData.account.encryptedSubstrateDerivationPath
        )

        // assert
        XCTAssertNotNil(encodedPath)
    }

    func testGetDecryptedWithError() throws {
        // arrange
        let service = EncryptionService()
        let message = TestData.substrateSeed

        // act & assert
        XCTAssertThrowsError(try service.getDecrypted(from: message, password: "1")) {
            guard case NaclSecretBox.NaclSecretBoxError.creationFailed = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testGetDecryptedRoundTrip() throws {
        // arrange
        let service = EncryptionService()
        let message = "carpet shiver bacon dirt sadness hammer isolate window"

        // act
        let encrypted = try XCTUnwrap(service.createEncryptedData(with: "1", message: message))
        let empty = try XCTUnwrap(service.createEncryptedData(with: "1", message: ""))

        // assert
        XCTAssertEqual(try service.getDecrypted(from: encrypted.toHex(), password: "1"), message)
        XCTAssertEqual(empty.count, ScryptParameters.minimumEncryptedLength)
        XCTAssertEqual(try service.getDecrypted(from: empty.toHex(), password: "1"), "")
    }

    func testGetDecryptedOpensExistingBackupCiphertext() throws {
        // act
        let decrypted = try EncryptionService().getDecrypted(
            from: TestData.keyVerifier,
            password: "1"
        )

        // assert
        XCTAssertEqual(decrypted, TestData.account.address)
    }

    func testGetDecryptedOpensOtherBoundedScryptParameters() throws {
        // arrange
        let encrypted = try encrypt("bounded", scryptN: 1024, scryptP: 2, scryptR: 4)

        // act
        let decrypted = try EncryptionService().getDecrypted(from: encrypted.toHex(), password: "1")

        // assert
        XCTAssertEqual(decrypted, "bounded")
    }

    func testGetDecryptedRejectsTruncatedNonce() throws {
        // arrange
        let service = EncryptionService()
        let encrypted = try encrypt("secret")
        let headerLength = ScryptParameters.encodedLength
        let nonceEnd = ScryptParameters.minimumEncryptedLength - ScryptParameters.macLength

        for length in [0, 1, headerLength - 1, headerLength, headerLength + 1, nonceEnd - 1] {
            let message = Data(encrypted.prefix(length)).toHex()

            // act & assert
            assertMalformed { try service.getDecrypted(from: message, password: "1") }
        }
    }

    func testGetDecryptedRejectsMissingMac() throws {
        // arrange
        let service = EncryptionService()
        let encrypted = try encrypt("secret")
        let nonceEnd = ScryptParameters.minimumEncryptedLength - ScryptParameters.macLength

        for length in [nonceEnd, ScryptParameters.minimumEncryptedLength - 1] {
            let message = Data(encrypted.prefix(length)).toHex()

            // act & assert
            assertMalformed { try service.getDecrypted(from: message, password: "1") }
        }
    }

    func testGetDecryptedRejectsOversizedInput() throws {
        // arrange
        let service = EncryptionService()
        let limit = ScryptParameters.maximumEncryptedLength
        let oversized = try ciphertext(length: limit + 1).toHex()
        let oversizedHex = String(repeating: "0", count: 2 * limit + 4)
        let largest = try ciphertext(scryptN: 2, scryptP: 1, scryptR: 1, length: limit)
            .toHex(includePrefix: true)

        // act & assert
        assertMalformed { try service.getDecrypted(from: oversized, password: "1") }
        assertMalformed { try service.getDecrypted(from: oversizedHex, password: "1") }
        // The largest accepted size reaches the MAC check, which this filler fails.
        XCTAssertThrowsError(try service.getDecrypted(from: largest, password: "1")) {
            guard case NaclSecretBox.NaclSecretBoxError.creationFailed = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testGetDecryptedRejectsExcessiveScryptParameters() throws {
        // arrange
        let parameters: [(scryptN: UInt32, scryptP: UInt32, scryptR: UInt32)] = [
            (0, 1, 8),
            (1, 1, 8),
            (32767, 1, 8),
            (1 << 19, 1, 8),
            (1 << 31, 1, 8),
            (UInt32.max, UInt32.max, UInt32.max),
            (32768, 0, 8),
            (32768, 17, 8),
            (32768, 1, 0),
            (32768, 1, 33),
        ]

        let service = EncryptionService()

        for (scryptN, scryptP, scryptR) in parameters {
            let message = try ciphertext(scryptN: scryptN, scryptP: scryptP, scryptR: scryptR)
                .toHex()

            // act & assert
            assertMalformed { try service.getDecrypted(from: message, password: "1") }
        }
    }

    func testGetDecryptedRejectsNonHexInput() {
        // arrange
        let service = EncryptionService()

        for message in ["zz", "abc", "0xzz"] {
            // act & assert
            assertMalformed { try service.getDecrypted(from: message, password: "1") }
        }
    }

    func testBackupRoundTrip() throws {
        // arrange
        let password = "backup password"
        let seed = "0x" + String(repeating: "ab", count: 32)
        let account = OpenBackupAccount(
            name: "chop",
            address: TestData.roundTripAddress,
            passphrase: "carpet shiver bacon dirt sadness hammer isolate window",
            cryptoType: "SR25519",
            substrateDerivationPath: "//soft/1",
            backupAccountType: [.passphrase, .seed, .json],
            json: OpenBackupAccount.Json(substrateJson: TestData.substrateJson),
            encryptedSeed: OpenBackupAccount.Seed(substrateSeed: seed)
        )
        let url = try BackupFileFactory(service: EncryptionService())
            .createFile(from: account, password: password)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        // act
        let opened = try CloudStorageService.openBackup(
            data,
            password: password,
            expectedAddress: account.address
        )

        // assert
        XCTAssertEqual(opened.name, account.name)
        XCTAssertEqual(opened.address, account.address)
        XCTAssertEqual(opened.passphrase, account.passphrase)
        XCTAssertEqual(opened.cryptoType, account.cryptoType)
        XCTAssertEqual(opened.substrateDerivationPath, account.substrateDerivationPath)
        XCTAssertNil(opened.ethDerivationPath)
        XCTAssertEqual(opened.backupAccountType, account.backupAccountType)
        XCTAssertEqual(opened.json, account.json)
        XCTAssertEqual(opened.encryptedSeed, account.encryptedSeed)
        XCTAssertThrowsError(try CloudStorageService.openBackup(data, password: "wrong")) {
            guard case CloudStorageServiceError.incorectPassword = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testOpenBackupRejectsOversizedFile() throws {
        // arrange
        let data = try backup(
            keyVerifier: encrypt(TestData.account.address).toHex(),
            mnemonic: encrypt("phrase").toHex()
        )
        // JSON allows trailing whitespace, so only the size limit rejects this.
        let padding = Data(
            repeating: UInt8(ascii: " "),
            count: EncryptionService.maximumBackupBytes + 1 - data.count
        )

        // act & assert
        XCTAssertEqual(try CloudStorageService.openBackup(data, password: "1").passphrase, "phrase")
        assertMalformed { try CloudStorageService.openBackup(data + padding, password: "1") }
    }

    func testOpenBackupReportsMalformedCiphertextAsIncorrectJson() throws {
        // arrange
        let keyVerifier = try encrypt(TestData.account.address).toHex()
        let mnemonic = try encrypt("phrase")
        let truncatedNonce = try backup(
            keyVerifier: keyVerifier,
            mnemonic: Data(mnemonic.prefix(ScryptParameters.encodedLength + 6)).toHex()
        )
        let excessiveVerifier = try backup(
            keyVerifier: ciphertext(scryptN: 1 << 20).toHex(),
            mnemonic: mnemonic.toHex()
        )
        let valid = try backup(keyVerifier: keyVerifier, mnemonic: mnemonic.toHex())

        // act & assert
        assertMalformed { try CloudStorageService.openBackup(truncatedNonce, password: "1") }
        assertMalformed { try CloudStorageService.openBackup(excessiveVerifier, password: "1") }
        XCTAssertThrowsError(try CloudStorageService.openBackup(valid, password: "wrong")) {
            guard case CloudStorageServiceError.incorectPassword = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }
}

private extension EncryptionServiceTests {
    func assertMalformed(
        _ operation: () throws -> Any?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) {
            guard case CloudStorageServiceError.incorectJson = $0 else {
                return XCTFail("Unexpected error: \($0)", file: file, line: line)
            }
        }
    }

    /// Encrypts like `EncryptionService.createEncryptedData`, with cheap scrypt
    /// parameters by default so the tests stay fast.
    func encrypt(
        _ message: String,
        scryptN: UInt32 = 2,
        scryptP: UInt32 = 1,
        scryptR: UInt32 = 1
    ) throws -> Data {
        let parameters = try ScryptParameters(
            salt: Data(repeating: 7, count: ScryptParameters.saltLength),
            scryptN: scryptN,
            scryptP: scryptP,
            scryptR: scryptR
        )
        let key = try IRScryptKeyDeriviation().deriveKey(
            from: Data("1".utf8),
            salt: parameters.salt,
            scryptN: UInt(scryptN),
            scryptP: UInt(scryptP),
            scryptR: UInt(scryptR),
            length: 32
        )
        let nonce = Data(repeating: 9, count: 24)
        let box = try NaclSecretBox.secretBox(message: Data(message.utf8), nonce: nonce, key: key)
        return parameters.encode() + nonce + box
    }

    /// A scrypt header followed by zero filler: well formed, but no MAC verifies.
    func ciphertext(
        scryptN: UInt32 = 32768,
        scryptP: UInt32 = 1,
        scryptR: UInt32 = 8,
        length: Int = 100
    ) throws -> Data {
        let header = try ScryptParameters(
            salt: Data(repeating: 7, count: ScryptParameters.saltLength),
            scryptN: scryptN,
            scryptP: scryptP,
            scryptR: scryptR
        ).encode()
        return header + Data(repeating: 0, count: length - header.count)
    }

    func backup(keyVerifier: String, mnemonic: String) throws -> Data {
        let account = EcryptedBackupAccount(
            name: "chop",
            address: TestData.account.address,
            keyVerifier: keyVerifier,
            encryptedMnemonicPhrase: mnemonic
        )
        return try JSONEncoder().encode(account)
    }
}

extension EncryptionServiceTests {
    enum TestData {
        static let substrateJson = """
        {\"address\":\"cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ\",\"encoded\":\"AAUbK8HDAE7Mw26rox6dktexv9pG5MRk\\/WtCJFtV2+kAgAAAAQAAAAgAAACivZKIFh9rMwauWG97MJ0ONwPg6eOpXNygK6X9RQfKMPvETRAfpHbRJp42LKEeWDNczqKaxltMj3yeMUi9kOYIz1sXMt7g7PC7aHUvSsF2G8nzV+XrNpC7nc8s+ty1OmVeKJWsSACfNj3OW9gxesmAtpfSrWx2ppSviKwvU1SKNYPfq+rxFCG+sXx4lggOFouAmT5iaPTL9fck\\/1vI\",\"encoding\":{\"content\":[\"pkcs8\",\"sr25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"meta\":{\"genesisHash\":\"0xded5a658e6ff2c82ce640caf8910ea2bb700aad5511ec7c3014cc7c256f5d956\",\"name\":\"chop\",\"whenCreated\":1706609064}}
        """

        static let substrateSeed = """
        0ffea7239c86f2c57976bb2ae65f0fe183ad40b5450edd2c0f2610aab80e9ae70080000001000000080000009f92ff8b19a2fc6eb7b68b746d9c6b6a21710d82b13704e62a7b90e402b8cd879b4f859f7da243bcc9f9674435e08fcd1a3562e500b99d3e40508bdd34e54819e3b79153097995f687ad3180852a3b1f05a657919ec8dcf2f0f0ed88693e0a263aa7ec0ff1106763e842
        """

        /// The key verifier of the existing backup fixture (N=32768, r=8, p=1),
        /// encrypted with password "1"; it decrypts to `account.address`.
        static let keyVerifier =
            "6b07b1cb82cb6f35db50385a3326f85554487de6cedcb4476cd0eca3b14cb04d00800000010000000800000061e9dee22479b55961bba585d2db532b7d5726dd5d6a4c9abab356fd20820eef884ead766256a06e1506a92503fb01a0ee4b889b6a77eafbf6bef710168b467797d69b44135f37ea8716339e5af9ef70b88933b24da89c7a81"

        static let roundTripAddress = "EncryptionServiceTestsRoundTrip"

        static let account = EcryptedBackupAccount(
            name: "chop",
            address: "cnSNFyYFzPPJWm1yKjZCKZnGhhrZWWx1Mme1gw64YvjJhNGoJ",
            encryptedMnemonicPhrase: nil,
            encryptedSubstrateDerivationPath: "5944fbdce78478ef92858817b176fe0b5b884e9c8652de8e10061f0680f83c3100800000010000000800000012e34d41a1843fe84e627672c688150b2ab19c12e7d6b77dab91457f3e8f06a1ca66218604f14691",
            encryptedEthDerivationPath: nil,
            cryptoType: "SR25519",
            backupAccountType: [
                "passphrase",
                "json",
                "seed",
            ],
            json: OpenBackupAccount
                .Json(substrateJson: substrateJson),
            encryptedSeed: OpenBackupAccount
                .Seed(substrateSeed: substrateSeed)
        )
    }
}
