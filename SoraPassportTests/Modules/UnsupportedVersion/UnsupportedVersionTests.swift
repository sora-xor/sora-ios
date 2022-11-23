import XCTest
@testable import SoraPassport
import Cuckoo

class UnsupportedVersionTests: XCTestCase {

    func testSetup() {
        // given

        let view = MockUnsupportedVersionViewProtocol()

        let supportedVersionData = SupportedVersionData(supported: false, updateUrl: Constants.dummyNetworkURL)
        let presenter = UnsupportedVersionPresenter(locale: Locale.current,
                                                    supportedVersionData: supportedVersionData)

        presenter.view = view

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any(UnsupportedVersionViewModel.self)).then { _ in
                expectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }
}
