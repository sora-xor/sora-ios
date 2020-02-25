/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo

class ProjectsEventCenterTests: NetworkBaseTests {

    func testViewEventDelivered() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsFetchMock.register(mock: .success, projectUnit: projectUnit)

        let eventCenter = EventCenter()
        let interactor = prepareListInteractor(with: eventCenter)
        let presenter = MockProjectsListInteractorOutputProtocol()
        interactor.presenter = presenter

        // when

        let projectId = UUID().uuidString

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub).didViewProject(with: projectId).then { _ in
                expectation.fulfill()
            }
        }

        interactor.setup()

        eventCenter.notify(with: ProjectViewEvent(projectId: projectId))

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testVoteEventDelivered() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsVotesCountMock.register(mock: .success, projectUnit: projectUnit)
        ProjectsVoteMock.register(mock: .success, projectUnit: projectUnit)

        let eventCenter = EventCenter()

        let interactor = prepareInteractor(with: eventCenter)

        let childPresenter = MockProjectsListPresenterProtocol()
        mockChildren(presenters: [childPresenter])

        let view = MockProjectsViewProtocol()
        let presenter = performPresenterSetup(for: interactor,
                                              view: view,
                                              children: [.all: childPresenter])

        // when

        stub(view) { stub in
            when(stub).didLoad(votes: any()).thenDoNothing()
            when(stub).didEditProjects(using: any((() -> ViewModelUpdateResult).self)).thenDoNothing()
        }

        let refreshExpectation = XCTestExpectation()

        stub(childPresenter) { stub in
            when(stub).refresh().then { _ in
                refreshExpectation.fulfill()
            }
        }

        let observer = MockEventVisitorProtocol()
        eventCenter.add(observer: observer)

        let observerExpectation = XCTestExpectation()

        stub(observer) { stub in
            when(stub).processProjectVote(event: any()).then { _ in
                observerExpectation.fulfill()
            }
        }

        interactor.vote(for: ProjectVote(projectId: UUID().uuidString, votes: "1.0"))

        // then

        wait(for: [refreshExpectation, observerExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertEqual(presenter.displayType, .all)
    }

    func testFavoriteToggleEventDelivered() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsVotesCountMock.register(mock: .success, projectUnit: projectUnit)
        ProjectsToggleFavoriteMock.register(mock: .success, projectUnit: projectUnit)

        let eventCenter = EventCenter()

        let interactor = prepareInteractor(with: eventCenter)

        let childPresenter = MockProjectsListPresenterProtocol()
        mockChildren(presenters: [childPresenter])

        let view = MockProjectsViewProtocol()
        let presenter = performPresenterSetup(for: interactor,
                                              view: view,
                                              children: [.all: childPresenter])

        // when

        stub(view) { stub in
            when(stub).didLoad(votes: any()).thenDoNothing()
            when(stub).didEditProjects(using: any((() -> ViewModelUpdateResult).self)).thenDoNothing()
        }

        let refreshExpectation = XCTestExpectation()

        stub(childPresenter) { stub in
            when(stub).refresh().then { _ in
                refreshExpectation.fulfill()
            }
        }

        let observer = MockEventVisitorProtocol()
        eventCenter.add(observer: observer)

        let observerExpectation = XCTestExpectation()

        stub(observer) { stub in
            when(stub).processProjectFavoriteToggle(event: any()).then { _ in
                observerExpectation.fulfill()
            }
        }

        interactor.toggleFavorite(for: UUID().uuidString)

        // then

        wait(for: [refreshExpectation, observerExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertEqual(presenter.displayType, .all)
    }

    // MARK: Private

    private func mockChildren(presenters: [MockProjectsListPresenterProtocol]) {
        for presenter in presenters {
            stub(presenter) { stub in
                when(stub).loadingState.get.thenReturn(.waitingCache)
                when(stub).numberOfProjects.get.thenReturn(1)
                when(stub).setFavorite(value: any(), for: any()).thenDoNothing()
                when(stub).refresh().thenDoNothing()
                when(stub).setup(layoutMetadata: any()).thenDoNothing()
                when(stub).view.set(any()).thenDoNothing()
            }
        }
    }

    private func performPresenterSetup(for interactor: ProjectsInteractor, view: MockProjectsViewProtocol, children: [ProjectDisplayType: ProjectsListPresenterProtocol]) -> ProjectsPresenter {
        let voteViewModelFactory = VoteViewModelFactory(amountFormatter: NumberFormatter.anyInteger.localizableResource())
        let presenter = ProjectsPresenter(children: children,
                                          voteViewModelFactory: voteViewModelFactory,
                                          votesDisplayFormatter: NumberFormatter.anyInteger
                                            .localizableResource())

        interactor.presenter = presenter
        presenter.interactor = interactor
        presenter.view = view

        let votesExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didLoad(votes: any()).then { _ in
                votesExpectation.fulfill()
            }
        }

        presenter.setup(layoutMetadata: ProjectLayoutMetadata.createDefault())

        wait(for: [votesExpectation], timeout: Constants.networkRequestTimeout)

        return presenter
    }

    private func prepareListInteractor(with eventCenter: EventCenterProtocol) -> ProjectsListInteractor {
        let mockedRequestSigner = createDummyRequestSigner()

        let coreDataCacheFacade = CoreDataCacheTestFacade()

        let projectDataProviderFacade = ProjectDataProviderFacade()
        projectDataProviderFacade.coreDataCacheFacade = coreDataCacheFacade
        projectDataProviderFacade.requestSigner = mockedRequestSigner

        return ProjectsListInteractor(projectsDataProvider: projectDataProviderFacade.allProjectsProvider,
                                      eventCenter: eventCenter)
    }

    private func prepareInteractor(with eventCenter: EventCenterProtocol) -> ProjectsInteractor {
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
}
