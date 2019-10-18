import XCTest
@testable import SoraPassport
import Cuckoo

class NetworkAvailabilityLayerTests: XCTestCase {
    func testRechanbilityChangeDisplayed() {
        // given

        let reachabilityManager = MockReachabilityManagerProtocol()

        let interactor = NetworkAvailabilityLayerInteractor(reachabilityManager: reachabilityManager)
        let presenter = NetworkAvailabilityLayerPresenter()
        let view = MockApplicationStatusPresentable()

        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        var delegate: ReachabilityListenerDelegate?

        let listenerAddExpectation = XCTestExpectation()
        listenerAddExpectation.assertForOverFulfill = true

        stub(reachabilityManager) { stub in
            when(stub).add(listener: any()).then { listener in
                delegate = listener

                listenerAddExpectation.fulfill()
            }

            when(stub).isReachable.get.thenReturn(false)
        }

        let reachabilityDisabledExpectation = XCTestExpectation()
        reachabilityDisabledExpectation.assertForOverFulfill = true

        let reachabilityEnabledExpectation = XCTestExpectation()
        reachabilityEnabledExpectation.assertForOverFulfill = true

        stub(view) { stub in
            when(stub).presentStatus(title: any(), style: any(), animated: any()).then { _ in
                reachabilityDisabledExpectation.fulfill()
            }

            when(stub).dismissStatus(title: any(), style: any(), animated: any()).then { _ in
                reachabilityEnabledExpectation.fulfill()
            }
        }

        interactor.setup()

        // then

        wait(for: [listenerAddExpectation, reachabilityDisabledExpectation], timeout: Constants.networkRequestTimeout)

        // when

        stub(reachabilityManager) { stub in
            when(stub).isReachable.get.thenReturn(true)
        }

        delegate?.didChangeReachability(by: reachabilityManager)

        // then

        wait(for: [reachabilityEnabledExpectation], timeout: Constants.networkRequestTimeout)
    }
}
