import XCTest
import SoraKeystore
import SSFUtils
@testable import SoraPassport

class KeystoreExportWrapperTests: XCTestCase {

    private let testMnemonic = "street firm worth record skin taste legend lobster magnet stove drive side"
    private let testRawSeed = "0xbf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61"
    private let username = "Test strit"
    private let password = "123123"

    func testExportSingleAccountIOS() {
        performExportTestForFilename("validSingleAccountIOS", username: username, password: password)
    }

    func testExportSingleAccountWeb() {
        performExportTestForFilename("validSingleAccountWeb", username: username, password: password)
    }

    func testExportSingleAccountFromMnemonic() {
        do {
            let expectedKeystore = InMemoryKeychain()
            let expectedSettings = InMemorySettingsManager()

            try? AccountCreationHelper.createAccountFromMnemonic(
                testMnemonic,
                cryptoType: .sr25519,
                name: username,
                networkType: .sora,
                keychain: expectedKeystore,
                settings: expectedSettings
            )

            let expectedAccountItem = expectedSettings.currentAccount!
            let expectedSecretKey = try expectedKeystore.fetchSecretKeyForAddress(expectedAccountItem.address)

            let exportData = try KeystoreExportWrapper(keystore: expectedKeystore).export(account: expectedAccountItem, password: password)

            let resultKeystore = InMemoryKeychain()
            let resultSettings = InMemorySettingsManager()

            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exportData)

            let info = try AccountImportJsonFactory().createInfo(from: definition)

            try AccountCreationHelper.createAccountFromKeystoreData(
                exportData,
                password: password,
                keychain: resultKeystore,
                settings: resultSettings,
                networkType: info.networkType ?? .sora,
                cryptoType: .sr25519,
                username: username
            )

            let resultAccountItem = resultSettings.currentAccount!
            let resultSecretKey = try expectedKeystore.fetchSecretKeyForAddress(resultAccountItem.address)

            XCTAssertEqual(expectedAccountItem, resultAccountItem)
            XCTAssertEqual(expectedSecretKey, resultSecretKey)

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }

    func testExportSingleAccountRawSeed() {
        do {

            let expectedKeystore = InMemoryKeychain()
            let expectedSettings = InMemorySettingsManager()

            try? AccountCreationHelper.createAccountFromMnemonic(
                testMnemonic,
                cryptoType: .sr25519,
                name: username,
                networkType: .sora,
                keychain: expectedKeystore,
                settings: expectedSettings
            )

            let account = expectedSettings.currentAccount!
            let secretKey = try expectedKeystore.fetchSecretKeyForAddress(account.address)

            let expectedSeedData = try expectedKeystore.fetchSeedForAddress(account.address)
            let expectedRawSeed = expectedSeedData?.toHex(includePrefix: true)

            XCTAssertEqual(testRawSeed, expectedRawSeed)

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }

    // MARK: Private

    private func performExportTestForFilename(_ name: String, username: String, password: String) {
        do {
            let expectedKeystore = InMemoryKeychain()
            let expectedSettings = InMemorySettingsManager()

            try AccountCreationHelper.createAccountFromKeystore(
                name,
                password: password,
                username: username,
                keychain: expectedKeystore,
                settings: expectedSettings
            )

            let expectedAccountItem = expectedSettings.currentAccount!
            let expectedSecretKey = try expectedKeystore.fetchSecretKeyForAddress(expectedAccountItem.address)

            let exportData = try KeystoreExportWrapper(keystore: expectedKeystore).export(account: expectedAccountItem, password: password)

            let resultKeystore = InMemoryKeychain()
            let resultSettings = InMemorySettingsManager()

            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exportData)

            let info = try AccountImportJsonFactory().createInfo(from: definition)

            try AccountCreationHelper.createAccountFromKeystoreData(
                exportData,
                password: password,
                keychain: resultKeystore,
                settings: resultSettings,
                networkType: info.networkType ?? .sora,
                cryptoType: .sr25519,
                username: username
            )

            let resultAccountItem = resultSettings.currentAccount!
            let resultSecretKey = try expectedKeystore.fetchSecretKeyForAddress(resultAccountItem.address)

            XCTAssertEqual(expectedAccountItem, resultAccountItem)
            XCTAssertEqual(expectedSecretKey, resultSecretKey)

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
}
