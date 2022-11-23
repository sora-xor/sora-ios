import XCTest
@testable import SoraPassport
import Cuckoo
import SoraFoundation

class LanguageSelectionTests: XCTestCase {

    func testSetupAndReceiveLanguagesAndSetNew() {
        // given

        let localizationManager = LocalizationManager(localization: Constants.englishLocalization)!

        let view = MockLanguageSelectionViewProtocol()
        let presenter = createPresenter(for: view, localizationManager: localizationManager)

        let loadingExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReload().then { _ in
                loadingExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [loadingExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertEqual(presenter.numberOfItems, localizationManager.availableLocalizations.count)

        // when

        presenter.selectItem(at: localizationManager.availableLocalizations.count - 1)

        // then

        XCTAssertEqual(localizationManager.selectedLocalization,
                       localizationManager.availableLocalizations.last)
    }

    // MARK: Private

    private func createPresenter(for view: LanguageSelectionViewProtocol,
                                 localizationManager: LocalizationManagerProtocol)
        -> LanguageSelectionPresenter {
        let presenter = LanguageSelectionPresenter()
        let wireframe = MockLanguageSelectionWireframeProtocol()
        let interactor = LanguageSelectionInteractor(localizationManager: localizationManager)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
