import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class ReferendumDetailsTests: NetworkBaseTests {
/*
    func testSuccessfullSetup() {
        // given
        ProjectsVotesCountMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        ReferendumDetailsFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let interactor = createInteractor(with: eventCenter)
        let presenter = MockReferendumDetailsInteractorOutputProtocol()
        interactor.presenter = presenter

        let votesExpectation = XCTestExpectation()
        votesExpectation.assertForOverFulfill = false

        let detailsExpectation = XCTestExpectation()
        detailsExpectation.assertForOverFulfill = false

        stub(presenter) { stub in
            when(stub).didReceive(votes: any(VotesData.self)).then { _ in
                votesExpectation.fulfill()
            }

            when(stub).didReceive(referendum: any(ReferendumData?.self)).then { _ in
                detailsExpectation.fulfill()
            }
        }

        // when
        interactor.setup()

        // then
        let expectations = [votesExpectation, detailsExpectation]
        wait(for: expectations, timeout: Constants.networkRequestTimeout)

        verify(presenter, atLeastOnce()).didReceive(votes: any(VotesData.self))
        verify(presenter, atLeastOnce()).didReceive(referendum: any(ReferendumData?.self))
    }

    // MARK: Private

    private func createInteractor(with eventCenter: EventCenterProtocol) -> ReferendumDetailsInteractor {
        let requestSigner = createDummyRequestSigner()

        let cacheFacade = CoreDataCacheTestFacade()

        let customerDataProviderFacade = CustomerDataProviderFacade()
        customerDataProviderFacade.coreDataCacheFacade = cacheFacade
        customerDataProviderFacade.requestSigner = requestSigner

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let detailsDataProviderFactory = ProjectDetailsDataProviderFactory(requestSigner: requestSigner,
                                                                           projectUnit: projectUnit)
        let detailsDataProvider = detailsDataProviderFactory
            .createReferendumDataProvider(for: Constants.dummyProjectId)!

        return ReferendumDetailsInteractor(customerDataProviderFacade: customerDataProviderFacade,
                                           referendumDetailsDataProvider: detailsDataProvider,
                                           projectService: ProjectUnitService(unit: projectUnit),
                                           eventCenter: eventCenter)
    }
*/
}
