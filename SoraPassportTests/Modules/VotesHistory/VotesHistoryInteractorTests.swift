import XCTest
@testable import SoraPassport
import Cuckoo
import RobinHood
import SoraFoundation

class VotesHistoryInteractorTests: NetworkBaseTests {
    /*
    func testSuccessfullSetupAndFirstPageLoading() {
        VotesHistoryFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interator = createInteractor()
        let presenter = createPresenter()
        let view = MockVotesHistoryViewProtocol()

        interator.presenter = presenter
        presenter.view = view
        presenter.interactor = interator

        performSetup(with: view, presenter: presenter)
    }

    func testDateFormatterChange() {
        // given

        VotesHistoryFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interator = createInteractor()
        let presenter = createPresenter()
        let view = MockVotesHistoryViewProtocol()

        interator.presenter = presenter
        presenter.view = view
        presenter.interactor = interator

        performSetup(with: view, presenter: presenter)

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReload().then {
                XCTAssert(Thread.isMainThread)
                expectation.fulfill()
            }
        }

        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: self)

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private

    private func performSetup(with view: MockVotesHistoryViewProtocol, presenter: VotesHistoryPresenter) {
        // given

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        stub(view) { (stub) in
            when(stub).didReload().then { _ in
                expectation.fulfill()
            }
        }

        // when
        presenter.setup()

        // then

        guard case .waitingCached = presenter.dataLoadingState else {
            XCTFail()
            return
        }

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        guard case .loaded(let page, _) = presenter.dataLoadingState, page == 0 else {
            XCTFail()
            return
        }

        verify(view, times(2)).didReload()
    }

    private func createInteractor() -> VotesHistoryInteractor {
        let requestSigner = createDummyRequestSigner()

        let votesHistoryDataProviderFactory = VotesHistoryDataProviderFactory(requestSigner: requestSigner,
                                                                              projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        votesHistoryDataProviderFactory.coreDataCacheFacade = CoreDataCacheTestFacade()

        let votesHistoryDataProvider = votesHistoryDataProviderFactory.createVotesHistoryDataProvider(with: VotesHistoryPresenter.eventsPerPage,
                                                                                                      updateTrigger: DataProviderEventTrigger.onNone)!

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        return VotesHistoryInteractor(votesHistoryDataProvider: votesHistoryDataProvider,
                                      projectService: projectService)
    }

    private func createPresenter() -> VotesHistoryPresenter {
        let dateFormatterProvider = DateFormatterProvider(dateFormatterFactory: EventListDateFormatterFactory.self,
                                                          dayChangeHandler: DayChangeHandler())

        let votesHistoryViewModelFactory = VotesHistoryViewModelFactory(amountFormatter: NumberFormatter.vote.localizableResource(),
                                                                        dateFormatterProvider: dateFormatterProvider)

        return VotesHistoryPresenter(locale: Locale.current,
                                     viewModelFactory: votesHistoryViewModelFactory)
    }
 */
}
