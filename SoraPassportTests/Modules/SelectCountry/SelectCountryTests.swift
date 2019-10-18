import XCTest
@testable import SoraPassport
import Cuckoo

class SelectCountryTests: NetworkBaseTests {

    func testSetupSearchAndSelect() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        CountryFetchMock.register(mock: .success, projectUnit: projectUnit)

        let interactor = createInteractor()
        let presenter = SelectCountryPresenter()
        let view = MockSelectCountryViewProtocol()
        let wireframe = MockSelectCountryWireframeProtocol()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        // when

        let setupExpectation = XCTestExpectation()
        setupExpectation.expectedFulfillmentCount = 2
        setupExpectation.assertForOverFulfill = true

        stub(view) { stub in
            when(stub).didReceive(viewModels: any([String].self)).then { _ in
                setupExpectation.fulfill()
            }
        }

        // then

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.networkRequestTimeout)

        // when

        let query = "japan"

        let searchExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showNext(from: any(), country: any()).then { (_, country) in
                XCTAssertTrue(country.name.localizedCaseInsensitiveCompare(query) == .orderedSame)
                searchExpectation.fulfill()
            }
        }

        stub(view) { stub in
            when(stub).controller.get.thenReturn(UIViewController())
            when(stub).didReceive(viewModels: any([String].self)).thenDoNothing()
        }

        // then

        presenter.search(by: query)
        presenter.select(at: 0)

        wait(for: [searchExpectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private

    private func createInteractor() -> SelectCountryInteractor {
        let requestSigner = createDummyRequestSigner()

        let informationFacade = InformationDataProviderFacade()
        informationFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        informationFacade.requestSigner = requestSigner

        return SelectCountryInteractor(countryProvider: informationFacade.countryDataProvider)
    }
}
