import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import SoraFoundation

class LocalAuthInteractorTests: XCTestCase {
    func testSuccessfullPincodeInput() {
        // given

        let view = MockPinSetupViewProtocol()
        let wireframe = MockPinSetupWireframeProtocol()
        let biometricAuth = MockBiometryAuthProtocol()

        let presenter = setup(view: view, wireframe: wireframe, biometricManager: biometricAuth)

        // when

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showMain(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        stub(biometricAuth) { stub in
            when(stub).availableBiometryType.get.thenReturn(.touchId)
            when(stub).authenticate(localizedReason: any(),
                                    completionQueue: any(),
                                    completionBlock: any()).thenDoNothing()
        }

        guard let interactor = presenter.interactor as? LocalAuthInteractor else {
            XCTFail("Unexpected interactor")
            return
        }

        var settings = interactor.settingsManager
        settings.biometryEnabled = false

        presenter.start()

        XCTAssert(interactor.state == .waitingPincode)

        presenter.submit(pin: Constants.dummyPincode)

        XCTAssert(interactor.state == .checkingPincode)

        // then

        wait(for: [completionExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssert(interactor.state == .completed)
    }

    func testSuccessfullBiometricAuth() {
        // given

        let view = MockPinSetupViewProtocol()
        let wireframe = MockPinSetupWireframeProtocol()
        let biometricAuth = MockBiometryAuthProtocol()

        let presenter = setup(view: view, wireframe: wireframe, biometricManager: biometricAuth)

        // when

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showMain(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        var biometricCompletionBlock: ((Bool) -> Void)?
        stub(biometricAuth) { stub in
            when(stub).availableBiometryType.get.thenReturn(.touchId)
            when(stub).authenticate(localizedReason: any(),
                                    completionQueue: any(),
                                    completionBlock: any()).then { _, _, completionBlock in
                biometricCompletionBlock = completionBlock
            }
        }

        guard let interactor = presenter.interactor as? LocalAuthInteractor else {
            XCTFail("Unexpected interactor")
            return
        }

        XCTAssert(interactor.state == .waitingPincode)

        presenter.start()

        XCTAssert(interactor.state == .checkingBiometry)

        biometricCompletionBlock?(true)

        // then

        wait(for: [completionExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssert(interactor.state == .completed)
    }

    func testPincodeInputWhileBiometricAuthInProgress() {
        // given

        let view = MockPinSetupViewProtocol()
        let wireframe = MockPinSetupWireframeProtocol()
        let biometricAuth = MockBiometryAuthProtocol()

        let presenter = setup(view: view, wireframe: wireframe, biometricManager: biometricAuth)

        // when

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showMain(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        let biometricRequestedExpectation = XCTestExpectation()
        stub(biometricAuth) { stub in
            when(stub).availableBiometryType.get.thenReturn(.touchId)
            when(stub).authenticate(localizedReason: any(),
                                    completionQueue: any(),
                                    completionBlock: any()).then { _, _, completionBlock in
                biometricRequestedExpectation.fulfill()
            }
        }

        guard let interactor = presenter.interactor as? LocalAuthInteractor else {
            XCTFail("Unexpected interactor")
            return
        }

        XCTAssert(interactor.state == .waitingPincode)

        presenter.start()

        XCTAssert(interactor.state == .checkingBiometry)

        presenter.submit(pin: Constants.dummyPincode)

        XCTAssert(interactor.state == .checkingPincode)

        // then

        wait(for: [completionExpectation, biometricRequestedExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssert(interactor.state == .completed)
    }

    // MARK: Private

    private func setup(view: MockPinSetupViewProtocol,
                       wireframe: MockPinSetupWireframeProtocol,
                       biometricManager: BiometryAuthProtocol) -> LocalAuthPresenter {

        let keystoreManager = InMemoryKeychainManager()
        let settingsManager = InMemorySettingsManager()

        try? keystoreManager.keychain.saveKey(Constants.dummyPincode.data(using: .utf8)!,
                                              with: KeystoreTag.pincode.rawValue)

        settingsManager.set(value: true, for: SettingsKey.biometryEnabled.rawValue)

        let interactor = LocalAuthInteractor(secretManager: keystoreManager,
                                             settingsManager: settingsManager,
                                             biometryAuth: biometricManager,
                                             locale: Locale.current)

        let presenter = LocalAuthPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        stub(view) { stub in
            when(stub).didChangeAccessoryState(enabled: any()).thenDoNothing()
            when(stub).didReceiveWrongPincode().thenDoNothing()
            when(stub).didRequestBiometryUsage(biometryType: any(), completionBlock: any()).thenDoNothing()
        }

        return presenter
    }
}
