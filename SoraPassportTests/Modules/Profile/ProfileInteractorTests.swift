import XCTest
import Cuckoo
import SoraKeystore
import RobinHood
@testable import SoraPassport

class ProfileInteractorTests: NetworkBaseTests {
    var interactor: ProfileInteractor!

    override func setUp() {
        super.setUp()

        let customerDataProviderFacade = CustomerDataProviderFacade()
        customerDataProviderFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        customerDataProviderFacade.requestSigner = createDummyRequestSigner()

        interactor = ProfileInteractor(customerDataProviderFacade: customerDataProviderFacade)
    }

    func testSuccessfullInteractorSetup() {
        // given
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        ProjectsVotesCountMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        ProjectsReputationFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        CurrencyFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let presenter = MockProfileInteractorOutputProtocol()
        interactor.presenter = presenter

        let userExpectation = XCTestExpectation()
        userExpectation.assertForOverFulfill = false

        let votesExpectation = XCTestExpectation()
        votesExpectation.assertForOverFulfill = false

        let reputationExpectation = XCTestExpectation()
        reputationExpectation.assertForOverFulfill = false

        stub(presenter) { stub in
            when(stub).didReceive(userData: any(UserData.self)).then { _ in
                userExpectation.fulfill()
            }

            when(stub).didReceive(votesData: any(VotesData.self)).then { _ in
                votesExpectation.fulfill()
            }

            when(stub).didReceive(reputationData: any(ReputationData.self)).then { _ in
                reputationExpectation.fulfill()
            }
        }

        // when

        interactor.setup()

        wait(for: [userExpectation, votesExpectation, reputationExpectation],
             timeout: Constants.networkRequestTimeout)

        // then
        verify(presenter, atLeastOnce()).didReceive(userData: any(UserData.self))
        verify(presenter, atLeastOnce()).didReceive(votesData: any(VotesData.self))
        verify(presenter, atLeastOnce()).didReceive(reputationData: any(ReputationData.self))
    }
}
