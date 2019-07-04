/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class ReputationInteractorTests: NetworkBaseTests {
    var interactor: ReputationInteractor!

    override func setUp() {
        super.setUp()

        let requestSigner = createDummyRequestSigner()
        let customerDataProviderFacade = CustomerDataProviderFacade()
        customerDataProviderFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        customerDataProviderFacade.requestSigner = requestSigner

        interactor = ReputationInteractor(customerDataProviderFacade: customerDataProviderFacade)
    }

    func testSuccessfullInteractorSetup() {
        // given
        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsReputationFetchMock.register(mock: .success, projectUnit: projectUnit)
        ProjectsVotesCountMock.register(mock: .success, projectUnit: projectUnit)

        let presenter = MockReputationInteractorOutputProtocol()
        interactor.presenter = presenter

        let reputationExpectation = XCTestExpectation()
        let votesExpectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub).didReceive(reputationData: any(ReputationData.self)).then { _ in
                reputationExpectation.fulfill()
            }

            when(stub).didReceive(votesData: any(VotesData.self)).then { _ in
                votesExpectation.fulfill()
            }
        }

        // when
        interactor.setup()

        wait(for: [reputationExpectation, votesExpectation], timeout: Constants.networkRequestTimeout)

        // then
        verify(presenter, times(1)).didReceive(reputationData: any(ReputationData.self))
        verify(presenter, times(1)).didReceive(votesData: any(VotesData.self))
    }
}
