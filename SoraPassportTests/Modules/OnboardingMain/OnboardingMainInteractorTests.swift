/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import SoraKeystore
import Cuckoo

class OnboardingMainInteractorTests: NetworkBaseTests {
    var interactor: OnboardingMainInteractor!

    override func setUp() {
        super.setUp()

        let settings = SettingsManager.shared
        let keystore = Keychain()

        let identityUrl = URL(string: ApplicationConfig.shared.didResolverUrl)!
        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: identityUrl)
        let projectOperationFactory = ProjectOperationFactory()

        interactor = OnboardingMainInteractor(applicationConfig: ApplicationConfig.shared,
                                              settings: settings,
                                              keystore: keystore,
                                              informationOperationFactory: projectOperationFactory,
                                              identityNetworkOperationFactory: identityNetworkOperationFactory,
                                              identityLocalOperationFactory: IdentityOperationFactory.self,
                                              operationManager: OperationManager.shared)

        clearStorage()
    }

    override func tearDown() {
        super.tearDown()

        clearStorage()
    }

    func testSignupPreparationWithVersionCheck() {
        performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: false)
    }

    func testSignupPreparationAfterVersionCheck() {
        performTestSuccessfullSignUp(with: true, expectsOnlyVersionCheck: false)
    }

    func testSignupWithPrecreatedIdentity() {
        let document = createIdentity()

        let decentralizedId = document.decentralizedId
        let publicKeyId = document.publicKey[0].pubKeyId

        var settings = interactor.settings
        settings.decentralizedId = decentralizedId
        settings.publicKeyId = publicKeyId
        settings.verificationState = VerificationState()

        let privateKey = try? interactor.keystore.fetchKey(for: KeystoreKey.privateKey.rawValue)

        performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: true)

        let expectedDecentralizedId = interactor.settings.decentralizedId!
        let expectedPublicKeyId = interactor.settings.publicKeyId!
        let expectedPrivateKey = try? Keychain().fetchKey(for: KeystoreKey.privateKey.rawValue)

        XCTAssertEqual(decentralizedId, expectedDecentralizedId)
        XCTAssertEqual(publicKeyId, expectedPublicKeyId)
        XCTAssertNotNil(privateKey)
        XCTAssertEqual(privateKey, expectedPrivateKey)
    }

    func testOnboardingPreparationForSignupWhenVerificationStateMissing() {
        do {
            let pincode = Constants.dummyPincode.data(using: .utf8)!

            try interactor.keystore.saveKey(pincode, with: KeystoreKey.pincode.rawValue)

            XCTAssertNil(interactor.settings.verificationState)

            performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: false)

            XCTAssertFalse(try interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue))

            XCTAssertNotNil(interactor.settings.verificationState)

        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testOnboardingPreparationForSignupWhenVerificationStateExists() {
        do {
            let pincode = Constants.dummyPincode.data(using: .utf8)!

            try interactor.keystore.saveKey(pincode, with: KeystoreKey.pincode.rawValue)

            var verificationState = VerificationState()
            verificationState.didPerformAttempt(with: Constants.networkRequestTimeout)
            interactor.settings.set(value: verificationState, for: SettingsKey.verificationState.rawValue)

            performTestSuccessfullSignUp(with: false, expectsOnlyVersionCheck: false)

            XCTAssertFalse(try interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue))

            XCTAssertEqual(interactor.settings.verificationState, verificationState)

        } catch {
            XCTFail("Unexpected error \(error)")
        }
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

        guard case .checkingVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        wait(for: [supportedExpectation], timeout: Constants.expectationDuration)

        guard case .checkedVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }

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

        guard case .checkingVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.prepareSignup()

        guard case .preparingSignup(let onlyVersionCheck) = interactor.state, !onlyVersionCheck else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        wait(for: [supportedExpectation], timeout: Constants.expectationDuration)

        guard case .checkedVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }

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

        guard case .checkingVersion = interactor.state else {
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

        guard case .checkingVersion = interactor.state else {
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

    private func performTestSuccessfullSignUp(with waitVersionCheck: Bool, expectsOnlyVersionCheck: Bool) {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        DecentralizedDocumentCreateMock.register(mock: .success)

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

            when(stub).didFinishSignupPreparation().then {
                signupEndExpectation.fulfill()
            }
        }

        // then

        guard case .initial = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        interactor.setup()

        guard case .checkingVersion = interactor.state else {
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

        guard case .checkedVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        XCTAssertNotNil(interactor.settings.decentralizedId)
        XCTAssertNotNil(interactor.settings.publicKeyId)

        let keystore = Keychain()

        guard let keyExists = try? keystore.checkKey(for: KeystoreKey.privateKey.rawValue), keyExists else {
            XCTFail()
            return
        }

        guard let entropyExists = try? keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue), entropyExists else {
            XCTFail()
            return
        }

        guard let pincodeExists = try? keystore.checkKey(for: KeystoreKey.pincode.rawValue), !pincodeExists else {
            XCTFail()
            return
        }
    }

    private func performTestFailIdentityCreation(with waitVersionCheck: Bool) {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
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

        guard case .checkingVersion = interactor.state else {
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

        guard case .checkingVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }

        if waitVersionCheck {
            wait(for: [versionExpectation], timeout: Constants.expectationDuration)
        }

        interactor.prepareRestore()

        if waitVersionCheck {
            guard case .checkedVersion = interactor.state else {
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

        guard case .checkedVersion = interactor.state else {
            XCTFail("Unexpected state \(interactor.state)")
            return
        }
    }

    private func clearStorage() {
        do {
            try Keychain().deleteAll()
            SettingsManager.shared.removeAll()
        } catch {
            XCTFail("\(error)")
        }
    }
}
