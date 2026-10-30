import IrohaCrypto
import SSFModels
import SSFUtils
import TweetNacl
import XCTest

// SSFUtils has no test target; Google Drive backups reach `KeystoreExtractor`
// through their JSON field, so the extractor bounds are tested here.
final class KeystoreExtractorTests: XCTestCase {
    func testBoundedEncryptedDataUsesRecoveryBounds() throws {
        // arrange
        let accepted: [(scryptN: UInt32, scryptP: UInt32, scryptR: UInt32)] = [
            (2, 1, 1),
            (16384, 1, 8),
            (32768, 1, 8),
            (262_144, 2, 8),
            (65536, 2, 32),
            (16384, 16, 16),
        ]
        let rejected: [(scryptN: UInt32, scryptP: UInt32, scryptR: UInt32)] = [
            (0, 1, 8),
            (1, 1, 8),
            (32767, 1, 8),
            (524_288, 1, 1),
            (UInt32.max, UInt32.max, UInt32.max),
            (32768, 0, 8),
            (32768, 17, 8),
            (32768, 1, 0),
            (32768, 1, 33),
            (262_144, 1, 16),
            (262_144, 3, 8),
            (131_072, 5, 8),
        ]
        let minimum = ScryptParameters.minimumEncryptedLength
        let limit = ScryptParameters.maximumEncryptedLength

        // act & assert
        for (scryptN, scryptP, scryptR) in accepted {
            let data = try payload(scryptN: scryptN, scryptP: scryptP, scryptR: scryptR)
            XCTAssertNotNil(ScryptParameters(boundedEncryptedData: data), "N=\(scryptN)")
        }
        for (scryptN, scryptP, scryptR) in rejected {
            let data = try payload(scryptN: scryptN, scryptP: scryptP, scryptR: scryptR)
            XCTAssertNil(ScryptParameters(boundedEncryptedData: data), "N=\(scryptN)")
        }
        for length in [minimum, limit] {
            let data = try payload(length: length)
            XCTAssertNotNil(ScryptParameters(boundedEncryptedData: data), "\(length)")
        }
        for length in [0, ScryptParameters.encodedLength, minimum - 1, limit + 1] {
            let data = try payload(length: length)
            XCTAssertNil(ScryptParameters(boundedEncryptedData: data), "\(length)")
        }
    }

    func testExtractorOpensAppStore386Keystore() throws {
        // arrange
        let definition = try JSONDecoder().decode(
            KeystoreDefinition.self,
            from: Data(TestData.appStore386Keystore.utf8)
        )
        let extractor = KeystoreExtractor()

        // act
        let keystore = try extractor.extractFromDefinition(
            definition,
            password: TestData.appStore386Password
        )

        // assert
        XCTAssertEqual(keystore.cryptoType, .ed25519)
        XCTAssertEqual(keystore.secretKeyData.toHex(), TestData.appStore386SecretKey)
        XCTAssertEqual(keystore.publicKeyData.toHex(), TestData.appStore386PublicKey)
        XCTAssertThrowsError(try extractor.extractFromDefinition(definition, password: "wrong")) {
            guard case NaclSecretBox.NaclSecretBoxError.creationFailed = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testExtractorRoundTrip() throws {
        // arrange
        let keystore = KeystoreData(
            address: nil,
            secretKeyData: TestData.secretKey,
            publicKeyData: TestData.publicKey,
            cryptoType: .ed25519
        )
        let definition = try KeystoreBuilder()
            .build(from: keystore, password: "password", isEthereum: false)

        // act
        let extracted = try KeystoreExtractor().extractFromDefinition(
            definition,
            password: "password"
        )

        // assert
        XCTAssertEqual(extracted, keystore)
    }

    func testExtractorOpensOlderScryptParameters() throws {
        // arrange
        let encoded = try encrypted(scryptN: 16384, scryptP: 1, scryptR: 8)

        // act
        let extracted = try KeystoreExtractor().extractFromDefinition(
            definition(encoded: encoded),
            password: "password"
        )

        // assert
        XCTAssertEqual(extracted.secretKeyData, TestData.secretKey)
        XCTAssertEqual(extracted.publicKeyData, TestData.publicKey)
    }

    func testExtractorRejectsTruncatedEncoded() throws {
        // arrange
        let encoded = try encrypted()
        let header = ScryptParameters.encodedLength
        let minimum = ScryptParameters.minimumEncryptedLength
        let nonceEnd = minimum - ScryptParameters.macLength

        for length in [1, header - 1, header, header + 6, nonceEnd - 1, nonceEnd, minimum - 1] {
            // act & assert
            assertUnsupported(definition(encoded: Data(encoded.prefix(length))))
        }
    }

    func testExtractorRejectsExcessiveScryptParameters() throws {
        // arrange
        let parameters: [(scryptN: UInt32, scryptP: UInt32, scryptR: UInt32)] = [
            (0, 1, 8),
            (32767, 1, 8),
            (1 << 19, 1, 8),
            (1 << 31, 1, 8),
            (UInt32.max, UInt32.max, UInt32.max),
            (32768, 0, 8),
            (32768, 17, 8),
            (32768, 1, 0),
            (32768, 1, 33),
            (262_144, 1, 16),
            (262_144, 3, 8),
        ]

        for (scryptN, scryptP, scryptR) in parameters {
            let encoded = try payload(scryptN: scryptN, scryptP: scryptP, scryptR: scryptR)

            // act & assert
            assertUnsupported(definition(encoded: encoded))
        }
    }

    func testExtractorRejectsOversizedEncoded() throws {
        // arrange
        let limit = ScryptParameters.maximumEncryptedLength
        let oversized = try payload(scryptN: 2, scryptP: 1, scryptR: 1, length: limit + 1)
        let largest = try payload(scryptN: 2, scryptP: 1, scryptR: 1, length: limit)

        // act & assert
        assertUnsupported(definition(encoded: oversized))
        // The largest accepted size reaches the MAC check, which this filler fails.
        XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(
            definition(encoded: largest),
            password: "password"
        )) {
            guard case NaclSecretBox.NaclSecretBoxError.creationFailed = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }
}

private extension KeystoreExtractorTests {
    func assertUnsupported(
        _ definition: KeystoreDefinition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try KeystoreExtractor().extractFromDefinition(definition, password: "password"),
            file: file,
            line: line
        ) {
            guard case KeystoreExtractorError.unsupportedEncoding = $0 else {
                return XCTFail("Unexpected error: \($0)", file: file, line: line)
            }
        }
    }

    func definition(encoded: Data) -> KeystoreDefinition {
        KeystoreDefinition(
            address: nil,
            encoded: encoded.base64EncodedString(),
            encoding: KeystoreEncoding(
                content: ["pkcs8", "ed25519"],
                type: ["scrypt", "xsalsa20-poly1305"],
                version: "3"
            ),
            meta: nil
        )
    }

    /// An Ed25519 keystore payload encrypted with "password", with cheap scrypt
    /// parameters by default so the tests stay fast.
    func encrypted(
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
            from: Data("password".utf8),
            salt: parameters.salt,
            scryptN: UInt(scryptN),
            scryptP: UInt(scryptP),
            scryptR: UInt(scryptR),
            length: 32
        )
        let nonce = Data(repeating: 9, count: 24)
        let pkcs8 = SSFUtils.KeystoreConstants.pkcs8Header + TestData.secretKey +
            SSFUtils.KeystoreConstants.pkcs8Divider + TestData.publicKey
        let box = try NaclSecretBox.secretBox(message: pkcs8, nonce: nonce, key: key)
        return parameters.encode() + nonce + box
    }

    /// A scrypt header followed by zero filler (or cut short): no MAC verifies.
    func payload(
        scryptN: UInt32 = 32768,
        scryptP: UInt32 = 1,
        scryptR: UInt32 = 8,
        length: Int = 200
    ) throws -> Data {
        let header = try ScryptParameters(
            salt: Data(repeating: 7, count: ScryptParameters.saltLength),
            scryptN: scryptN,
            scryptP: scryptP,
            scryptR: scryptR
        ).encode()
        let filled = header + Data(repeating: 0, count: max(length - header.count, 0))
        return Data(filled.prefix(length))
    }
}

private extension KeystoreExtractorTests {
    enum TestData {
        static let secretKey = Data(repeating: 1, count: 32)
        static let publicKey = Data(repeating: 2, count: 32)

        /// `exportedJSON` of `ios-386-ed25519-3words-1` in
        /// SoraPassportTests/Common/Modernization/HistoricalCrypto/ios-386-vectors.json,
        /// written by the App Store 3.8.6 shared-features build (N=32768, r=8, p=1).
        static let appStore386Keystore = """
        {"address":"cnUmbhFDT8FYAw7nvxFdJm7ZrTJAN6KqGguJaYrUmn8ZAihcQ","encoded":"VRcZIZIyfdnvmqtJ0C01vghgKFfumeY+e77K6J2UrUwAgAAAAQAAAAgAAAAaCZivIm29zHBN6iP3JjaTtOMlqQtRa3lO4Xb1YKlL0hPz5S6DmeJt2aOT7AcgZjmBD5KXtN8F9FLawM5mcYDXzG3TAG+y87myS1yUzya0xkhoD7ds2BPCJ1iCJ9oTqRjCBidR1g3dVHYwHIdg8OVIJCuA8zjLxtq0XcEC/Q==","encoding":{"content":["pkcs8","ed25519"],"type":["scrypt","xsalsa20-poly1305"],"version":"3"},"meta":{"name":"ios-386-ed25519-3words-1","whenCreated":0}}
        """
        static let appStore386Password = "public-json-fixture-password"
        static let appStore386SecretKey =
            "4ed8d4b17698ddeaa1f1559f152f87b5d472f725ca86d341bd0276f1b61197e2"
        static let appStore386PublicKey =
            "9125f505bdef2cb5825b9931769316d3e2f22150786489a04f39b434ec9fb294"
    }
}
