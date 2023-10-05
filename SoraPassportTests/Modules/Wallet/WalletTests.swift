import XCTest
@testable import SoraPassport
import SoraKeystore

class WalletTests: XCTestCase {
    private(set) var keystore = Keychain()
    private(set) var settings = SettingsManager.shared

    override func setUp() {
        try? keystore.deleteAll(for: "")
        settings.removeAll()
    }

    override func tearDown() {
        try? keystore.deleteAll(for: "")
        settings.removeAll()
    }
}
