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
                                            settings: settings)
    }

    override func tearDown() {
        clearStorage()
    }

    func testSuccessfullPassphraseLoading() {
        // given

        try? interactor.keystore.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreTag.pincode.rawValue)

        let mnemonic = try! interactor.mnemonicCreator.mnemonic(fromList: Constants.dummyValidMnemonic)
        try? interactor.keystore.saveEntropy(mnemonic.entropy(), address: settings.selectedAccount!.address)

        let presenter = MockAccountCreateInteractorOutputProtocol()// MockAccessBackupInteractorOutputProtocol()
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub).didReceive(metadata: any(AccountCreationMetadata.self)).then { _ in
                expectation.fulfill()
            }
        }

        // when

        interactor.setup()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        verify(presenter, times(1)).didReceive(metadata: any(AccountCreationMetadata.self))
    }

    // MARK: Private

    func clearStorage() {
        do {
            try interactor.keystore.deleteAll()
        } catch {
            XCTFail("\(error)")
        }
    }
}
