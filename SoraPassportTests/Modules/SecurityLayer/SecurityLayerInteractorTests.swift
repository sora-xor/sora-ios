import XCTest
@testable import SoraPassport
import Cuckoo
import SoraFoundation
import SoraKeystore

class SecurityLayerInteractorTests: XCTestCase {
    func testSecuredOverlayAppearanceAndDismissing() {
        // given
        let mockApplicationHandler = MockApplicationHandlerProtocol()
        let settings = InMemorySettingsManager()
        let keystore = InMemoryKeychain()

        let pincodeDelay: TimeInterval = 1.0

        let interactor = SecurityLayerInteractor(applicationHandler: mockApplicationHandler,
                                                 settings: settings,
                                                 keystore: keystore,
                                                 pincodeDelay: pincodeDelay)

        let presenter = SecurityLayerPresenter()
        let wireframe = MockSecurityLayerWireframProtocol()

        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        expectation.assertForOverFulfill = true

        stub(wireframe) { stub in
            when(stub).showSecuringOverlay().then {
                expectation.fulfill()
            }

            when(stub).hideSecuringOverlay().then {
                expectation.fulfill()
            }
        }

        stub(mockApplicationHandler) { stub in
            when(stub).delegate.set(any()).thenDoNothing()
        }

        // when
        interactor.setup()

        interactor.didReceiveWillResignActive(notification: Notification(name: UIApplication.willResignActiveNotification))
        interactor.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testPincodeRequestWhenAppInActiveLong() {
        // given

        let mockApplicationHandler = MockApplicationHandlerProtocol()

        var settings = InMemorySettingsManager()
        settings.decentralizedId = Constants.dummyDid

        let keystore = InMemoryKeychain()
        try! keystore.addKey(Data(), with: KeystoreTag.pincode.rawValue)

        let pincodeDelay: TimeInterval = 0.25

        let interactor = SecurityLayerInteractor(applicationHandler: mockApplicationHandler,
                                                 settings: settings,
                                                 keystore: keystore,
                                                 pincodeDelay: pincodeDelay)

        let presenter = SecurityLayerPresenter()
        let wireframe = MockSecurityLayerWireframProtocol()

        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true

        stub(wireframe) { stub in
            when(stub).showSecuringOverlay().then {
                expectation.fulfill()
            }

            when(stub).hideSecuringOverlay().then {
                expectation.fulfill()
            }

            when(stub).showAuthorization().then {
                expectation.fulfill()
            }
        }

        stub(mockApplicationHandler) { stub in
            when(stub).delegate.set(any()).thenDoNothing()
        }

        // when
        interactor.setup()

        interactor.didReceiveWillResignActive(notification: Notification(name: UIApplication.willResignActiveNotification))

        usleep(UInt32(2 * 1000000 * pincodeDelay))

        interactor.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)
    }
}
