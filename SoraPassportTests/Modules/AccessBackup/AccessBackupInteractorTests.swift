import XCTest
@testable import SoraPassport
import IrohaCrypto
import SoraKeystore
import Cuckoo

class AccessBackupInteractorTests: XCTestCase {
    var interactor: AccountBackupInteractor!
    let settings = InMemorySettingsManager()

    override func setUp() {
        super.setUp()

        let keystore = InMemoryKeychain()


        try? AccountCreationHelper.createAccountFromMnemonic(Constants.dummyValidMnemonic,
                                                            cryptoType: .sr25519,
                                                            networkType: .sora,
                                                            keychain: keystore,
                                                            settings: settings)

        interactor = AccountBackupInteractor(keystore: keystore,
                                            mnemonicCreator: IRMnemonicCreator(language: .english),
                                             account: settings.currentAccount!)
    }

    override func tearDown() {
        clearStorage()
    }

    // MARK: Private

    func clearStorage() {
        do {
            try interactor.keystore.deleteAll(for: "")
        } catch {
            XCTFail("\(error)")
        }
    }
}
