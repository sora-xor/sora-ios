/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import IrohaCrypto

class AccountRestoreInteractorTests: NetworkBaseTests {
    var interactor: AccessRestoreInteractor!

    override func setUp() {
        super.setUp()

        interactor = AccessRestoreInteractor(accountOperationFactory: ProjectOperationFactory(),
                                             identityLocalOperationFactory: IdentityOperationFactory.self,
                                             keystore: Keychain(),
                                             operationManager: OperationManager.shared,
                                             applicationConfig: ApplicationConfig.shared,
                                             settings: SettingsManager.shared,
                                             mnemonicCreator: IRBIP39MnemonicCreator(language: .english))
        clearStorage()
    }

    override func tearDown() {
        clearStorage()

        super.tearDown()
    }

    func testSuccessfullRestorationImmediately() {
        performTestSuccessfullRestoration()
    }

    func testSuccessfullRestorationAfterTryingRegistration() {
        var settings = interactor.settings
        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId
        settings.verificationState = VerificationState()

        performTestSuccessfullRestoration()
    }

    private func performTestSuccessfullRestoration() {
        // given
        ProjectsCustomerMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        try? interactor.keystore.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreKey.pincode.rawValue)

        let finishExpectation = XCTestExpectation()

        let presenterMock = MockAccessRestoreInteractorOutputProtocol()

        stub(presenterMock) { stub in
            when(stub.didRestoreAccess(from: any([String].self))).then { _ in
                finishExpectation.fulfill()
            }
            when(stub.didReceiveRestoreAccess(error: any(Error.self))).thenDoNothing()
        }

        interactor.presenter = presenterMock

        interactor.restoreAccess(phrase: Constants.dummyValidMnemonic.components(separatedBy: CharacterSet.wordsSeparator))

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)

        verify(presenterMock, times(1)).didRestoreAccess(from: any([String].self))
        verify(presenterMock, times(0)).didReceiveRestoreAccess(error: any(Error.self))

        XCTAssertNotNil(interactor.settings.decentralizedId)
        XCTAssertNotNil(interactor.settings.publicKeyId)
        XCTAssertNil(interactor.settings.verificationState)

        guard let keyExists = try? interactor.keystore.checkKey(for: KeystoreKey.privateKey.rawValue), keyExists else {
            XCTFail()
            return
        }

        guard let seedEntropyExists = try? interactor.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue), seedEntropyExists else {
            XCTFail()
            return
        }

        guard let pincodeExists = try? interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue), !pincodeExists else {
            XCTFail()
            return
        }
    }

    // MARK: Private

    func clearStorage() {
        do {
            try interactor.keystore.deleteAll()
            interactor.settings.removeAll()
        } catch {
            XCTFail("\(error)")
        }
    }
}
