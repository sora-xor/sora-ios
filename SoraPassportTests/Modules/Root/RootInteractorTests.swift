/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
import Cuckoo
@testable import SoraPassport
import SoraKeystore

class RootInteractorTests: XCTestCase {
    var view: UIWindow!
    var presenter: RootPresenter!
    var interactor: RootInteractor!
    var wireframe: MockRootWireframeProtocol!

    private(set) var keystore = Keychain()
    private(set) var settings = SettingsManager.shared

    override func setUp() {
        try? keystore.deleteAll()
        settings.removeAll()

        defaultSetup()
    }

    override func tearDown() {
        try? keystore.deleteAll()
        settings.removeAll()
    }

    func testDecidedOnboardingWhenNoDecentralizedId() {
        performTestDecidedOnboarding()
    }

    func testDecidedOnboardingWhenDecentralizedIdAndVerificationStateExists() {
        settings.decentralizedId = Constants.dummyDid

        var verificationState = VerificationState()
        verificationState.didPerformAttempt(with: Constants.networkRequestTimeout)
        settings.verificationState = verificationState

        performTestDecidedOnboarding()

        XCTAssertEqual(settings.verificationState, verificationState)
        XCTAssertEqual(settings.decentralizedId, Constants.dummyDid)
    }

    private func performTestDecidedOnboarding() {
        // given
        let viewMatcher = ParameterMatcher<UIWindow> { $0 === self.view }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showOnboarding(on: viewMatcher)).then { view in
                expectation.fulfill()
            }
        }

        // when
        presenter.loadOnLaunch()

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testDecideAuthVerification() {
        // given
        let viewMatcher = ParameterMatcher<UIWindow> { $0 === self.view }

        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showAuthVerification(on: viewMatcher)).then { view in
                expectation.fulfill()
            }
        }

        // when
        presenter.loadOnLaunch()

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertEqual(settings.decentralizedId, Constants.dummyDid)
        XCTAssertNil(settings.verificationState)
    }

    func testDecideLocalAuth() {
        // given
        let viewMatcher = ParameterMatcher<UIWindow> { $0 === self.view }

        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId

        try? keystore.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreKey.pincode.rawValue)

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showLocalAuthentication(on: viewMatcher)).then { view in
                expectation.fulfill()
            }
        }

        // when
        presenter.loadOnLaunch()

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertEqual(settings.decentralizedId, Constants.dummyDid)
        XCTAssertNil(settings.verificationState)
    }

    // MARK: Private

    private func defaultSetup() {
        view = UIWindow()
        presenter = RootPresenter()
        wireframe = MockRootWireframeProtocol()
        let securityLayerInteractor = MockSecurityLayerInteractorInputProtocol()
        let networkAvailabilityLayer = MockNetworkAvailabilityLayerInteractorInputProtocol()

        stub(securityLayerInteractor) { stub in
            when(stub).setup().thenDoNothing()
        }

        stub(networkAvailabilityLayer) { stub in
            when(stub).setup().thenDoNothing()
        }

        interactor = RootInteractor(settings: SettingsManager.shared,
                                    keystore: Keychain(),
                                    securityLayerInteractor: securityLayerInteractor,
                                    networkAvailabilityLayerInteractor: networkAvailabilityLayer)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter
    }
}
