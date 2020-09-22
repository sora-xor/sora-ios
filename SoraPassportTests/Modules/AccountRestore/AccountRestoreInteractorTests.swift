import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import IrohaCrypto
import SoraFoundation

class AccountRestoreInteractorTests: NetworkBaseTests {
    var interactor: AccessRestoreInteractor!

    override func setUp() {
        super.setUp()

        let settings = InMemorySettingsManager()

        interactor = AccessRestoreInteractor(identityLocalOperationFactory: IdentityOperationFactory(),
                                             accountOperationFactory: ProjectOperationFactory(),
                                             keystore: InMemoryKeychain(),
                                             settings: settings,
                                             applicationConfig: ApplicationConfig.shared,
                                             mnemonicCreator: IRMnemonicCreator(language: .english),
                                             invitationLinkService: InvitationLinkService(settings: settings),
                                             operationManager: OperationManagerFacade.sharedManager)
    }

    func testSuccessfullRestorationImmediately() throws {
        try performTestSuccessfullRestoration()
    }

    func testSuccessfullRestorationAfterTryingRegistration() throws {
        var settings = interactor.settings
        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId
        settings.verificationState = VerificationState()

        XCTAssertTrue(interactor.invitationLinkService.handle(url: Constants.dummyInvitationLink))

        try performTestSuccessfullRestoration()
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

        interactor.restoreAccess(mnemonic: Constants.dummyInvalidMnemonic)

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

        interactor.restoreAccess(mnemonic: Constants.dummyValidMnemonic)

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)
    }

    func testStateNotChangedWhenMnemonicInvalid() throws {
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

        let document = createIdentity(with: interactor.keystore)

        var settings = interactor.settings
        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        let verificationState = VerificationState(resendDelay: 60.0, lastAttempted: Date())
        settings.verificationState = verificationState

        let newPrivateKey = try IRIrohaKeyFactory().createRandomKeypair()

        try interactor.keystore.saveKey(newPrivateKey.privateKey().rawData(), with: KeystoreKey.privateKey.rawValue)

        let secondaryRepository = SecondaryIdentityRepository(keystore: interactor.keystore)
        try secondaryRepository.generateAndSaveForAll()

        let secondaryKeys = try secondaryRepository.fetchAll()

        // when

        interactor.restoreAccess(mnemonic: Constants.dummyValidMnemonic)

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertEqual(settings.decentralizedId, document.decentralizedId)
        XCTAssertEqual(settings.publicKeyId, document.publicKey.first!.pubKeyId)
        XCTAssertEqual(settings.verificationState, verificationState)

        let currentPrivateKeyData = try interactor.keystore.fetchKey(for: KeystoreKey.privateKey.rawValue)

        let expectedSecondaryKeys = try secondaryRepository.fetchAll()

        XCTAssertEqual(newPrivateKey.privateKey().rawData(), currentPrivateKeyData)
        XCTAssertEqual(secondaryKeys, expectedSecondaryKeys)
    }

    // MARK: Private

    private func performTestSuccessfullRestoration() throws {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)

        let finishExpectation = XCTestExpectation()

        let presenterMock = MockAccessRestoreInteractorOutputProtocol()

        stub(presenterMock) { stub in
            when(stub.didRestoreAccess(from: any(String.self))).then { _ in
                finishExpectation.fulfill()
            }
            when(stub.didReceiveRestoreAccess(error: any(Error.self))).thenDoNothing()
        }

        interactor.presenter = presenterMock

        interactor.restoreAccess(mnemonic: Constants.dummyValidMnemonic)

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)

        verify(presenterMock, times(1)).didRestoreAccess(from: any(String.self))
        verify(presenterMock, times(0)).didReceiveRestoreAccess(error: any(Error.self))

        XCTAssertNotNil(interactor.settings.decentralizedId)
        XCTAssertNotNil(interactor.settings.publicKeyId)
        XCTAssertNil(interactor.settings.verificationState)
        XCTAssertNil(interactor.invitationLinkService.link)

        XCTAssertTrue(try interactor.keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
        XCTAssertTrue(try interactor.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try SecondaryIdentityRepository(keystore: interactor.keystore).checkAllExist())
    }
}
