/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
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

        let settings = InMemorySettingsManager()

        interactor = AccessRestoreInteractor(identityLocalOperationFactory: IdentityOperationFactory.self,
                                             accountOperationFactory: ProjectOperationFactory(),
                                             keystore: InMemoryKeychain(),
                                             settings: settings,
                                             applicationConfig: ApplicationConfig.shared,
                                             mnemonicCreator: IRBIP39MnemonicCreator(language: .english),
                                             invitationLinkService: InvitationLinkService(settings: settings),
                                             operationManager: OperationManager.shared)
    }

    func testSuccessfullRestorationImmediately() {
        performTestSuccessfullRestoration()
    }

    func testSuccessfullRestorationAfterTryingRegistration() {
        var settings = interactor.settings
        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId
        settings.verificationState = VerificationState()

        XCTAssertTrue(interactor.invitationLinkService.handle(url: Constants.dummyInvitationLink))

        performTestSuccessfullRestoration()
    }

    func testRestorationWithInvalidMnemonic() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)

        let finishExpectation = XCTestExpectation()

        let presenterMock = MockAccessRestoreInteractorOutputProtocol()

        stub(presenterMock) { stub in
            when(stub.didReceiveRestoreAccess(error: any(Error.self))).then { _ in
                finishExpectation.fulfill()
            }
        }

        interactor.presenter = presenterMock

        // when

        interactor.restoreAccess(phrase: Constants.dummyInvalidMnemonic.components(separatedBy: CharacterSet.wordsSeparator))

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)
    }

    func testRestorationWithNotExistingMnemonic() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .resourceNotFound, projectUnit: projectUnit)

        let finishExpectation = XCTestExpectation()

        let presenterMock = MockAccessRestoreInteractorOutputProtocol()

        stub(presenterMock) { stub in
            when(stub.didReceiveRestoreAccess(error: any(Error.self))).then { _ in
                finishExpectation.fulfill()
            }
        }

        interactor.presenter = presenterMock

        // when

        interactor.restoreAccess(phrase: Constants.dummyValidMnemonic.components(separatedBy: CharacterSet.wordsSeparator))

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)
    }

    func testStateNotChangedWhenMnemonicInvalid() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .unauthorized, projectUnit: projectUnit)

        let finishExpectation = XCTestExpectation()

        let presenterMock = MockAccessRestoreInteractorOutputProtocol()

        stub(presenterMock) { stub in
            when(stub.didReceiveRestoreAccess(error: any(Error.self))).then { _ in
                finishExpectation.fulfill()
            }
        }

        interactor.presenter = presenterMock

        let document = createIdentity()

        var settings = interactor.settings
        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        let verificationState = VerificationState(resendDelay: 60.0, lastAttempted: Date())
        settings.verificationState = verificationState

        guard let newPrivateKey = IREd25519KeyFactory().createRandomKeypair() else {
            XCTFail()
            return
        }

        XCTAssertNoThrow(try interactor.keystore.saveKey(newPrivateKey.privateKey().rawData(),
                                                         with: KeystoreKey.privateKey.rawValue))

        // when

        interactor.restoreAccess(phrase: Constants.dummyValidMnemonic.components(separatedBy: CharacterSet.wordsSeparator))

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertEqual(settings.decentralizedId, document.decentralizedId)
        XCTAssertEqual(settings.publicKeyId, document.publicKey.first!.pubKeyId)
        XCTAssertEqual(settings.verificationState, verificationState)

        let currentPrivateKeyData = try? interactor.keystore.fetchKey(for: KeystoreKey.privateKey.rawValue)

        XCTAssertEqual(newPrivateKey.privateKey().rawData(), currentPrivateKeyData)
    }

    // MARK: Private

    private func performTestSuccessfullRestoration() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)

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
        XCTAssertNil(interactor.invitationLinkService.link)

        guard let keyExists = try? interactor.keystore.checkKey(for: KeystoreKey.privateKey.rawValue), keyExists else {
            XCTFail()
            return
        }

        guard let seedEntropyExists = try? interactor.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue), seedEntropyExists else {
            XCTFail()
            return
        }
    }
}
