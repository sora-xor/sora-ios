/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport


class ProjectsInteractorTests: NetworkBaseTests {

    func testMainSuccessfullSetup() {
        // given
        ProjectsVotesCountMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        CurrencyFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let interactor = createProjectsInteractor(with: eventCenter)
        let presenter = MockProjectsInteractorOutputProtocol()
        interactor.presenter = presenter

        let votesExpectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub).didReceive(votes: any(VotesData.self)).then { _ in
                votesExpectation.fulfill()
            }
        }

        // when
        interactor.setup()

        let expectations = [votesExpectation]
        wait(for: expectations, timeout: Constants.expectationDuration)

        // then
        verify(presenter, atLeastOnce()).didReceive(votes: any(VotesData.self))
    }

    func testListSuccessfullSetupTest() {
        ProjectsFinishedFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let interactor = createListInteractor(with: eventCenter)
        let presenter = createListPresenter()
        let view = MockProjectsListViewProtocol()
        interactor.presenter = presenter
        presenter.interactor = interactor
        presenter.view = view

        performSetup(for: view, presenter: presenter)
    }

    func testDayChangeAfterListSetup() {
        // given

        ProjectsFinishedFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let interactor = createListInteractor(with: eventCenter)
        let presenter = createListPresenter()
        let view = MockProjectsListViewProtocol()
        interactor.presenter = presenter
        presenter.interactor = interactor
        presenter.view = view

        // when

        performSetup(for: view, presenter: presenter)

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReloadProjects(using: any()).then { _ in
                XCTAssert(Thread.isMainThread)
                expectation.fulfill()
            }
        }

        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: self)

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private

    func performSetup(for view: MockProjectsListViewProtocol, presenter: ProjectsListPresenter) {
        // given

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        stub(view) { stub in
            when(stub).didEditProjects(using: any((() -> ViewModelUpdateResult).self)).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.setup(layoutMetadata: ProjectLayoutMetadata.createDefault())

        wait(for: [expectation], timeout: 2 * Constants.networkRequestTimeout)

        // then

        XCTAssertEqual(presenter.loadingState, .loaded)
    }

    func createProjectsInteractor(with eventCenter: EventCenterProtocol) -> ProjectsInteractor {
        let mockedRequestSigner = createDummyRequestSigner()

        let coreDataCacheFacade = CoreDataCacheTestFacade()

        let customerDataProviderFacade = CustomerDataProviderFacade()
        customerDataProviderFacade.coreDataCacheFacade = coreDataCacheFacade
        customerDataProviderFacade.requestSigner = mockedRequestSigner

        let projectDataProviderFacade = ProjectDataProviderFacade()
        projectDataProviderFacade.coreDataCacheFacade = coreDataCacheFacade
        projectDataProviderFacade.requestSigner = mockedRequestSigner

        let informationFacade = InformationDataProviderFacade()
        informationFacade.coreDataCacheFacade = coreDataCacheFacade
        informationFacade.requestSigner = mockedRequestSigner

        let projectUnitService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectUnitService.requestSigner = mockedRequestSigner

        return ProjectsInteractor(customerDataProviderFacade: customerDataProviderFacade,
                                  projectService: projectUnitService,
                                  eventCenter: eventCenter)
    }

    func createListInteractor(with eventCenter: EventCenterProtocol) -> ProjectsListInteractor {
        let mockedRequestSigner = createDummyRequestSigner()

        let projectDataProviderFacade = ProjectDataProviderFacade()
        projectDataProviderFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        projectDataProviderFacade.requestSigner = mockedRequestSigner

        return ProjectsListInteractor(projectsDataProvider: projectDataProviderFacade.finishedProjectsProvider,
                                      eventCenter: eventCenter)
    }

    func createListPresenter() -> ProjectsListPresenter {
        let projectViewModelFactory = ProjectViewModelFactory.createDefault()
        return ProjectsListPresenter(viewModelFactory: projectViewModelFactory)
    }
}
