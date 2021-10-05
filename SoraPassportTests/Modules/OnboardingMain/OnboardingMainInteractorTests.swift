import XCTest
@testable import SoraPassport
import SoraKeystore
import Cuckoo

class OnboardingMainInteractorTests: NetworkBaseTests {
    /*
    var interactor: OnboardingMainInteractor!

    override func setUp() {
        super.setUp()

        let settings = InMemorySettingsManager()
        let keystore = InMemoryKeychain()

        let identityUrl = URL(string: ApplicationConfig.shared.didResolverUrl)!
        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: identityUrl)
        let projectOperationFactory = ProjectOperationFactory()

        let invitationLinkService = InvitationLinkService(settings: settings)

        let onboardingPreparationService = OnboardingPreparationService(
            accountOperationFactory: projectOperationFactory,
            informationOperationFactory: projectOperationFactory,
            invitationLinkService: invitationLinkService,
            deviceInfoFactory: DeviceInfoFactory(),
            keystore: keystore,
            settings: settings,
            applicationConfig: ApplicationConfig.shared)

        interactor = OnboardingMainInteractor(onboardingPreparationService: onboardingPreparationService,
                                              settings: settings,
                                              keystore: keystore,
                                              identityNetworkOperationFactory: identityNetworkOperationFactory,
                                              identityLocalOperationFactory: IdentityOperationFactory(),
                                              operationManager: OperationManagerFacade.sharedManager)
    }

    func testSignupPreparationWithVersionCheck() throws {
        try performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: false)
    }

    func testSignupPreparationAfterVersionCheck() throws {
        try performTestSuccessfullSignUp(with: true, expectsOnlyVersionCheck: false)
    }

    func testSignupWithPrecreatedIdentity() throws {
        let document = createIdentity(with: interactor.keystore)

        let decentralizedId = document.decentralizedId
        let publicKeyId = document.publicKey[0].pubKeyId

        var settings = interactor.settings
        settings.decentralizedId = decentralizedId
        settings.publicKeyId = publicKeyId
        settings.verificationState = VerificationState()

        let secondaryIdentityRepository = SecondaryIdentityRepository(keystore: interactor.keystore)

        let privateKey = try interactor.keystore.fetchKey(for: KeystoreKey.privateKey.rawValue)
        let secondaryKeys = try secondaryIdentityRepository.fetchAll()

        try performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: true)

        let expectedDecentralizedId = interactor.settings.decentralizedId!
        let expectedPublicKeyId = interactor.settings.publicKeyId!
        let expectedPrivateKey = try interactor.keystore.fetchKey(for: KeystoreKey.privateKey.rawValue)
        let expectedSecondaryKeys = try secondaryIdentityRepository.fetchAll()

        XCTAssertEqual(decentralizedId, expectedDecentralizedId)
        XCTAssertEqual(publicKeyId, expectedPublicKeyId)
        XCTAssertEqual(privateKey, expectedPrivateKey)
        XCTAssertEqual(secondaryKeys, expectedSecondaryKeys)
    }

    func testOnboardingPreparationForSignupWhenVerificationStateMissing() throws {
        let pincode = Constants.dummyPincode.data(using: .utf8)!

        try interactor.keystore.saveKey(pincode, with: KeystoreKey.pincode.rawValue)

        XCTAssertNil(interactor.settings.verificationState)

        try performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: false)

        XCTAssertFalse(try interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue))

        XCTAssertNotNil(interactor.settings.verificationState)
    }

    func testOnboardingPreparationForSignupWhenVerificationStateExists() throws {
        let pincode = Constants.dummyPincode.data(using: .utf8)!

        try interactor.keystore.saveKey(pincode, with: KeystoreKey.pincode.rawValue)

        var verificationState = VerificationState()
        verificationState.didPerformAttempt(with: Constants.networkRequestTimeout)
        interactor.settings.set(value: verificationState, for: SettingsKey.verificationState.rawValue)

        try performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: false)

        XCTAssertFalse(try interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue))

        XCTAssertEqual(interactor.settings.verificationState, verificationState)
    }

    func testOnboardingPreparationForRestore() {
        do {
            let pincode = Constants.dummyPincode.data(using: .utf8)!

            try interactor.keystore.saveKey(pincode, with: KeystoreKey.pincode.rawValue)
            interactor.settings.set(value: VerificationState(), for: SettingsKey.verificationState.rawValue)

            performTestSuccessfullRestorePreparation(with: false)

            XCTAssertFalse(try interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue))
            XCTAssertNotNil(interactor.settings.verificationState)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testSignupPreparationWithVersionCheckWhenIdentityCreationFails() {
        performTestFailIdentityCreation(with: false)
    }

    func testSignupPreparationAfterVersionCheckWhenIdentityCreationFails() {
        performTestFailIdentityCreation(with: true)
    }

    func testRestorePreparationWithVersionCheck() {
        performTestSuccessfullRestorePreparation(with: false)
    }

    func testRestorePreparationAfterVersionCheck() {
        performTestSuccessfullRestorePreparation(with: true)
    }

    func testUnsupportedVersionOnSetup() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .unsupported, projectUnit: projectUnit)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let supportedExpectation = XCTestExpectation()

        // when

        stub(presenter) { stub in
            when(stub).didReceiveVersion(data: any(SupportedVersionData.self)).then { data in
                XCTAssertTrue(!data.supported)

                supportedExpectation.fulfill()
            }
        }

        // then

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        wait(for: [supportedExpectation], timeout: Constants.expectationDuration)

        guard case .prepared = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }
/*
    func testUnsupportedVersionOnPreparationSignup() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .unsupported, projectUnit: projectUnit)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let supportedExpectation = XCTestExpectation()

        // when

        stub(presenter) { stub in
            when(stub).didReceiveVersion(data: any(SupportedVersionData.self)).then { data in
                XCTAssertTrue(!data.supported)

                supportedExpectation.fulfill()
            }

            when(stub).didStartSignupPreparation().thenDoNothing()
        }

        // then

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.prepareSignup()

        guard case .preparingSignup(let onlyVersionCheck) = interactor.state, !onlyVersionCheck else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        wait(for: [supportedExpectation], timeout: Constants.expectationDuration)

        guard case .prepared = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }
*/
    func testFailRestorePreparation() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .notFound, projectUnit: projectUnit)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let restoreStartExpectation = XCTestExpectation()
        restoreStartExpectation.assertForOverFulfill = true

        let restoreEndExpectation = XCTestExpectation()
        restoreEndExpectation.assertForOverFulfill = true

        // when

        stub(presenter) { stub in
            when(stub).didStartRestorePreparation().then {
                restoreStartExpectation.fulfill()
            }

            when(stub).didReceiveRestorePreparation(error: any(Error.self)).then { error in
                restoreEndExpectation.fulfill()
            }
        }

        // then

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.prepareRestore()

        guard case .preparingRestoration = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        wait(for: [restoreStartExpectation, restoreEndExpectation], timeout: Constants.expectationDuration)

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }

    func testFailCheckVersionWhenSignupPreparation() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .notFound, projectUnit: projectUnit)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let signupStartExpectation = XCTestExpectation()
        signupStartExpectation.assertForOverFulfill = true

        let signupEndExpectation = XCTestExpectation()
        signupEndExpectation.assertForOverFulfill = true

        // when

        stub(presenter) { stub in
            when(stub).didStartSignupPreparation().then {
                signupStartExpectation.fulfill()
            }

            when(stub).didReceiveSignupPreparation(error: any(Error.self)).then { error in
                signupEndExpectation.fulfill()
            }
        }

        // then

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.prepareSignup()

        guard case .preparingSignup(let onlyVersionCheck) = interactor.state, !onlyVersionCheck else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        wait(for: [signupStartExpectation, signupEndExpectation], timeout: Constants.expectationDuration)

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }

    // MARK: Private

    private func performTestSuccessfullSignUp(with waitVersionCheck: Bool, expectsOnlyVersionCheck: Bool) throws {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        CheckInvitationMock.register(mock: .success, projectUnit: projectUnit)
        DecentralizedDocumentCreateMock.register(mock: .success)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let versionExpectation = XCTestExpectation()
        versionExpectation.assertForOverFulfill = true

        let signupStartExpectation = XCTestExpectation()
        signupStartExpectation.assertForOverFulfill = true

        let signupEndExpectation = XCTestExpectation()
        signupEndExpectation.assertForOverFulfill = true

        let invitationCodeSavedExpectation = XCTestExpectation()
        invitationCodeSavedExpectation.assertForOverFulfill = true

        // when

        stub(presenter) { stub in
            when(stub).didReceiveVersion(data: any(SupportedVersionData.self)).then { data in
                XCTAssertTrue(data.supported)
                versionExpectation.fulfill()
            }

            when(stub).didStartSignupPreparation().then {
                signupStartExpectation.fulfill()
            }

            when(stub).didFinishSignupPreparation().then {
                signupEndExpectation.fulfill()
            }
        }

        let invitationLinkObserver = MockInvitationLinkObserver()

        if let service = interactor.onboardingPreparationService as? OnboardingPreparationService {
            stub(invitationLinkObserver) { stub in
                stub.didUpdateInvitationLink(from: any()).then { _ in
                    invitationCodeSavedExpectation.fulfill()
                }
            }

            service.invitationLinkService.add(observer: invitationLinkObserver)
        }

        // then

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        if waitVersionCheck {
            wait(for: [versionExpectation], timeout: Constants.expectationDuration)
        }

        interactor.prepareSignup()

        guard case .preparingSignup(let onlyVersionCheck) = interactor.state, onlyVersionCheck == expectsOnlyVersionCheck else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        if waitVersionCheck {
            wait(for: [signupStartExpectation, signupEndExpectation], timeout: Constants.expectationDuration)
        } else {
            wait(for: [signupStartExpectation, versionExpectation, signupEndExpectation], timeout: Constants.expectationDuration)
        }

        wait(for: [invitationCodeSavedExpectation], timeout: Constants.expectationDuration)

        verify(invitationLinkObserver, times(1)).didUpdateInvitationLink(from: any())

        guard case .prepared = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        XCTAssertNotNil(interactor.settings.decentralizedId)
        XCTAssertNotNil(interactor.settings.publicKeyId)

        XCTAssertNotNil(interactor.settings.isCheckedInvitation)
        XCTAssertNotNil(interactor.settings.invitationCode)

        XCTAssertTrue(try interactor.keystore.checkKey(for: KeystoreKey.privateKey.rawValue))
        XCTAssertTrue(try interactor.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue))
        XCTAssertTrue(try SecondaryIdentityRepository(keystore: interactor.keystore).checkAllExist())

        XCTAssertFalse(try interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue))
    }

    private func performTestFailIdentityCreation(with waitVersionCheck: Bool) {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        CheckInvitationMock.register(mock: .success, projectUnit: projectUnit)
        DecentralizedDocumentCreateMock.register(mock: .notFound)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let versionExpectation = XCTestExpectation()
        versionExpectation.assertForOverFulfill = true

        let signupStartExpectation = XCTestExpectation()
        signupStartExpectation.assertForOverFulfill = true

        let signupEndExpectation = XCTestExpectation()
        signupEndExpectation.assertForOverFulfill = true

        // when

        stub(presenter) { stub in
            when(stub).didReceiveVersion(data: any(SupportedVersionData.self)).then { data in
                XCTAssertTrue(data.supported)
                versionExpectation.fulfill()
            }

            when(stub).didStartSignupPreparation().then {
                signupStartExpectation.fulfill()
            }

            when(stub).didReceiveSignupPreparation(error: any(Error.self)).then { error in
                signupEndExpectation.fulfill()
            }
        }

        // then

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        if waitVersionCheck {
            wait(for: [versionExpectation], timeout: Constants.expectationDuration)
        }

        interactor.prepareSignup()

        guard case .preparingSignup(let onlyVersionCheck) = interactor.state, !onlyVersionCheck else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        if waitVersionCheck {
            wait(for: [signupStartExpectation, signupEndExpectation], timeout: Constants.expectationDuration)
        } else {
            wait(for: [signupStartExpectation, versionExpectation, signupEndExpectation], timeout: Constants.expectationDuration)
        }

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }

    private func performTestSuccessfullRestorePreparation(with waitVersionCheck: Bool) {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        CheckInvitationMock.register(mock: .success, projectUnit: projectUnit)

        let presenter = MockOnboardingMainOutputInteractorProtocol()
        interactor.presenter = presenter

        let versionExpectation = XCTestExpectation()
        versionExpectation.assertForOverFulfill = true

        let restoreStartExpectation = XCTestExpectation()
        restoreStartExpectation.assertForOverFulfill = true

        let restoreEndExpectation = XCTestExpectation()
        restoreEndExpectation.assertForOverFulfill = true

        // when

        stub(presenter) { stub in
            when(stub).didReceiveVersion(data: any(SupportedVersionData.self)).then { data in
                XCTAssertTrue(data.supported)
                versionExpectation.fulfill()
            }

            when(stub).didStartRestorePreparation().then {
                restoreStartExpectation.fulfill()
            }

            when(stub).didFinishRestorePreparation().then {
                restoreEndExpectation.fulfill()
            }
        }

        // then

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.setup()

        guard case .preparing = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        if waitVersionCheck {
            wait(for: [versionExpectation], timeout: Constants.expectationDuration)
        }

        interactor.prepareRestore()

        if waitVersionCheck {
            guard case .prepared = interactor.state else {
                XCTFail("Unexpected state \(interactor.state)")
                return
            }
        } else {
            guard case .preparingRestoration = interactor.state else {
                XCTFail("Unexpected state \(interactor.state)")
                return
            }
        }

        if waitVersionCheck {
            wait(for: [restoreEndExpectation], timeout: Constants.expectationDuration)
        } else {
            wait(for: [restoreStartExpectation, versionExpectation, restoreEndExpectation], timeout: Constants.expectationDuration)
        }

        guard case .prepared = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }
 */
}
