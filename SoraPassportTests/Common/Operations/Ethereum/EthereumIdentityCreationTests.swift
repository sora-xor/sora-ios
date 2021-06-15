import XCTest
@testable import SoraPassport
import SoraKeystore
import IrohaCrypto

class EthereumIdentityCreationTests: XCTestCase {
    private let keystore = Keychain()

    override func setUp() {
        try? keystore.deleteAll()
    }

    override func tearDown() {
        try? keystore.deleteAll()
    }
/*
    func testIdentityCreationSuccess() throws {
        // given

        try generateAndSaveMnemonic()

        // when

        try EthereumIdentityService().createIdentity(using: keystore, skipIfExists: false)

        // then

        XCTAssertTrue(try keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try keystore.checkKey(for: KeystoreKey.ethKey.rawValue))
    }

    func testIdentityNotReplacedWhenExists() throws {
        // given

        let privateKey = try generateAndSavePrivateKey()

        // when

        try EthereumIdentityService().createIdentity(using: keystore, skipIfExists: true)

        // then

        let resultPrivateKey = try keystore.fetchKey(for: KeystoreKey.ethKey.rawValue)
        XCTAssertEqual(privateKey, resultPrivateKey)
    }

    func testIdentityReplacedWhenExists() throws {
        // given

        let privateKey = try generateAndSavePrivateKey()

        try generateAndSaveMnemonic()

        // when

        try EthereumIdentityService().createIdentity(using: keystore, skipIfExists: false)

        // then

        let resultPrivateKey = try keystore.fetchKey(for: KeystoreKey.ethKey.rawValue)
        XCTAssertNotEqual(resultPrivateKey, privateKey)
    }

    // MARK: Private

    @discardableResult
    private func generateAndSaveMnemonic() throws -> Data {
        let entropy = try IRMnemonicCreator().mnemonic(fromList: Constants.dummyValidMnemonic).entropy()
        try keystore.saveKey(entropy, with: KeystoreKey.seedEntropy.rawValue)

        return entropy
    }

    @discardableResult
    private func generateAndSavePrivateKey() throws -> Data {
        let privateKey = Data(repeating: 0, count: 32)
        try keystore.saveKey(privateKey, with: KeystoreKey.ethKey.rawValue)

        return privateKey
    }
 */
}
