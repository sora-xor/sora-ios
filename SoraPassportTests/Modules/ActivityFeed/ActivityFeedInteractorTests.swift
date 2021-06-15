import XCTest
@testable import SoraPassport
import Cuckoo
import RobinHood
import SoraFoundation

class ActivityFeedInteractorTests: NetworkBaseTests {
/*
    func testSuccessfullSetupAndFirstPageLoading() {
        ActivityFeedMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        AnnouncementFetchMock.register(mock: .successNotEmpty, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interactor = createInteractor()
        let presenter = createPresenter()
        let viewMock = MockActivityFeedViewProtocol()
        let wireframe = MockActivityFeedWireframeProtocol()

        interactor.presenter = presenter
        presenter.view = viewMock
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        performSetup(for: viewMock, presenter: presenter, wireframe: wireframe)
    }

    func testSectionDateFormatterChanges() {
        // given

        ActivityFeedMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        AnnouncementFetchMock.register(mock: .successNotEmpty, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interactor = createInteractor()
        let presenter = createPresenter()
        let view = MockActivityFeedViewProtocol()
        let wireframe = MockActivityFeedWireframeProtocol()

        interactor.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        performSetup(for: view, presenter: presenter, wireframe: wireframe)

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(using: any((() -> ActivityFeedStateChange).self)).then { _ in
                XCTAssert(Thread.isMainThread)
                expectation.fulfill()
            }
        }

        // day changed notification usually dispatched in background

        DispatchQueue.global(qos: .default).async {
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: self)
        }

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testActivityFeedLoadingFailure() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ActivityFeedMock.register(mock: .internalError, projectUnit: projectUnit)
        AnnouncementFetchMock.register(mock: .successNotEmpty, projectUnit: projectUnit)

        let interactor = createInteractor()
        let presenter = createPresenter()
        let view = MockActivityFeedViewProtocol()
        let wireframe = MockActivityFeedWireframeProtocol()

        interactor.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        performSetup(for: view, presenter: presenter, wireframe: wireframe, expectsError: true)

        // when

        let expectation = XCTestExpectation()

        ActivityFeedMock.register(mock: .success, projectUnit: projectUnit)

        stub(view) { stub in
            when(stub).didReceive(using: any((() -> ActivityFeedStateChange).self)).then { _ in
                expectation.fulfill()
            }

            when(stub).controller.get.thenReturn(UIViewController())
        }

        XCTAssert(presenter.reload())

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    // MARK: Private

    private func performSetup(for view: MockActivityFeedViewProtocol,
                              presenter: ActivityFeedPresenter,
                              wireframe: MockActivityFeedWireframeProtocol,
                              expectsError: Bool = false) {
        // given

        let itemsExpectation = XCTestExpectation()
        itemsExpectation.expectedFulfillmentCount = expectsError ? 1 : 2
        itemsExpectation.assertForOverFulfill = false

        let announcementExpectation = XCTestExpectation()
        announcementExpectation.expectedFulfillmentCount = 2
        announcementExpectation.assertForOverFulfill = false

        stub(view) { (stub) in
            when(stub).didReceive(using: any((() -> ActivityFeedStateChange).self)).then { _ in
                itemsExpectation.fulfill()
            }

            when(stub).didReload(announcement: any(AnnouncementItemViewModelProtocol?.self)).then { _ in
                announcementExpectation.fulfill()
            }

            when(stub).itemLayoutMetadataContainer.get.then { _ in
                return ActivityFeedLayoutMetadataContainer(basicLayoutMetadata: ActivityFeedItemLayoutMetadata(),
                                                           amountLayoutMetadata: ActivityFeedAmountItemLayoutMetadata())
            }

            when(stub).announcementLayoutMetadata.get.then { _ in
                return AnnouncementItemLayoutMetadata()
            }

            when(stub).controller.get.thenReturn(UIViewController())
            when(stub).isSetup.get.thenReturn(true)
        }

        var expectations: [XCTestExpectation] = [itemsExpectation, announcementExpectation]

        if expectsError {
            let errorExpectation = XCTestExpectation()
            expectations.append(errorExpectation)

            stub(wireframe) { stub in
                when(stub).present(error: any(), from: any(), locale: any()).then { _ in
                    errorExpectation.fulfill()
                    return true
                }
            }
        }


        // when
        presenter.setup()

        // then

        guard case .waitingCached = presenter.dataLoadingState else {
            XCTFail()
            return
        }

        wait(for: expectations, timeout: Constants.networkRequestTimeout)

        if !expectsError {
            guard case .loaded(let page, _) = presenter.dataLoadingState, page == 0 else {
                XCTFail()
                return
            }
        }

        verify(view, times(2)).didReceive(using: any((() -> ActivityFeedStateChange).self))
        verify(view, atLeast(2)).didReload(announcement: any(AnnouncementItemViewModelProtocol?.self))
    }

    private func createInteractor() -> ActivityFeedInteractor {
        let requestSigner = createDummyRequestSigner()

        let coreDataCacheFacade = CoreDataCacheTestFacade()

        let activityFeedDataProviderFactory = ActivityFeedDataProviderFactory(requestSigner: requestSigner,
                                                                              projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        activityFeedDataProviderFactory.coreDataCacheFacade = coreDataCacheFacade

        let activityFeedDataProvider = activityFeedDataProviderFactory.createActivityFeedDataProvider(with: ActivityFeedPresenter.eventsPerPage,
                                                                                                      updateTrigger: DataProviderEventTrigger.onNone)!

        let informationDataProviderFacade = InformationDataProviderFacade()
        informationDataProviderFacade.coreDataCacheFacade = coreDataCacheFacade
        informationDataProviderFacade.requestSigner = requestSigner

        let announcementDataProvider = informationDataProviderFacade.announcementDataProvider

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        return ActivityFeedInteractor(activityFeedDataProvider: activityFeedDataProvider,
                                      announcementDataProvider: announcementDataProvider,
                                      projectService: projectService)
    }

    private func createPresenter() -> ActivityFeedPresenter {
        let dateFormatterProvider = DateFormatterProvider(dateFormatterFactory: EventListDateFormatterFactory.self,
                                                          dayChangeHandler: DayChangeHandler())

        let activityFeedViewModelFactory = ActivityFeedViewModelFactory(sectionFormatterProvider: dateFormatterProvider,
                                                                        timestampDateFormatter: DateFormatter.timeOnly
                                                                            .localizableResource(),
                                                                        votesNumberFormatter: NumberFormatter.vote
                                                                            .localizableResource(),
                                                                        amountFormatter: NumberFormatter.amount
                                                                            .localizableResource(),
                                                                        integerFormatter: NumberFormatter.anyInteger
                                                                            .localizableResource())

        let announcementViewModelFactory = AnnouncementViewModelFactory()

        return ActivityFeedPresenter(itemViewModelFactory: activityFeedViewModelFactory,
                                     announcementViewModelFactory: announcementViewModelFactory)
    }
 */
}
