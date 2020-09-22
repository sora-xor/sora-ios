import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class ProjectDetailsInteractorTests: NetworkBaseTests {

    func testSuccessfullSetup() {
        // given
        ProjectsVotesCountMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        ProjectDetailsFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        CurrencyFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let interactor = createInteractor(with: eventCenter)
        let presenter = MockProjectDetailsInteractorOutputProtocol()
        interactor.presenter = presenter

        let votesExpectation = XCTestExpectation()
        votesExpectation.assertForOverFulfill = false

        let projectDetailsExpectation = XCTestExpectation()
        projectDetailsExpectation.assertForOverFulfill = false

        stub(presenter) { stub in
            when(stub).didReceive(votes: any(VotesData.self)).then { _ in
                votesExpectation.fulfill()
            }

            when(stub).didReceive(projectDetails: any(ProjectDetailsData?.self)).then { _ in
                projectDetailsExpectation.fulfill()
            }
        }

        // when
        interactor.setup()

        // then
        let expectations = [votesExpectation, projectDetailsExpectation]
        wait(for: expectations, timeout: Constants.networkRequestTimeout)

        verify(presenter, atLeastOnce()).didReceive(votes: any(VotesData.self))
        verify(presenter, atLeastOnce()).didReceive(projectDetails: any(ProjectDetailsData?.self))
    }

    // MARK: Private

    private func createInteractor(with eventCenter: EventCenterProtocol) -> ProjectDetailsInteractor {
        let requestSigner = createDummyRequestSigner()

        let cacheFacade = CoreDataCacheTestFacade()

        let customerDataProviderFacade = CustomerDataProviderFacade()
        customerDataProviderFacade.coreDataCacheFacade = cacheFacade
        customerDataProviderFacade.requestSigner = requestSigner

        let informationFacade = InformationDataProviderFacade()
        informationFacade.coreDataCacheFacade = cacheFacade
        informationFacade.requestSigner = requestSigner

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let detailsDataProviderFactory = ProjectDetailsDataProviderFactory(requestSigner: requestSigner,
                                                                           projectUnit: projectUnit)
        let detailsDataProvider = detailsDataProviderFactory.createDetailsDataProvider(for: Constants.dummyProjectId)!

        return ProjectDetailsInteractor(customerDataProviderFacade: customerDataProviderFacade,
                                        projectDetailsDataProvider: detailsDataProvider,
                                        projectService: ProjectUnitService(unit: projectUnit),
                                        eventCenter: eventCenter)
    }
}
