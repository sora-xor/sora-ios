/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import IrohaCrypto
import SoraKeystore
import Cuckoo

class AccessBackupInteractorTests: XCTestCase {
    var interactor: AccessBackupInteractor!

    override func setUp() {
        super.setUp()

        interactor = AccessBackupInteractor(keystore: Keychain(),
                                            mnemonicCreator: IRMnemonicCreator(language: .english))

        clearStorage()
    }

    override func tearDown() {
        clearStorage()
    }

    func testSuccessfullPassphraseLoading() {
        // given

        try? interactor.keystore.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreKey.pincode.rawValue)

        let mnemonic = try! interactor.mnemonicCreator.mnemonic(fromList: Constants.dummyValidMnemonic)
        try? interactor.keystore.saveKey(mnemonic.entropy(), with: KeystoreKey.seedEntropy.rawValue)

        let presenter = MockAccessBackupInteractorOutputProtocol()
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub).didLoad(mnemonic: any(String.self)).then { _ in
                expectation.fulfill()
            }
        }

        // when

        interactor.load()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        verify(presenter, times(1)).didLoad(mnemonic: Constants.dummyValidMnemonic)
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
