import XCTest
@testable import SoraPassport

class RootFactoryTests: XCTestCase {
    func testPresenterCreation() {
        let optionalPresenter = RootPresenterFactory.createPresenter(with: SoraWindow()) as? RootPresenter

        guard let presenter = optionalPresenter else {
            XCTFail()
            return
        }

        XCTAssertNotNil(presenter.view)
        XCTAssertNotNil(presenter.wireframe)

        guard let interactor = presenter.interactor as? RootInteractor else {
            XCTFail()
            return
        }

        XCTAssertNotNil(interactor.presenter)
    }

}
