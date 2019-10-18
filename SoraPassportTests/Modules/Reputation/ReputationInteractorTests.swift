/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
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

        let informationProviderFacade = InformationDataProviderFacade()
        informationProviderFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        informationProviderFacade.requestSigner = requestSigner

        interactor = ReputationInteractor(reputationProvider: customerDataProviderFacade.reputationDataProvider,
                                          reputationDetailsProvider: informationProviderFacade.reputationDetailsProvider,
                                          votesProvider: customerDataProviderFacade.votesProvider)
    }

    func testSuccessfullInteractorSetup() {
        // given
        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsReputationFetchMock.register(mock: .success, projectUnit: projectUnit)
        ProjectsVotesCountMock.register(mock: .success, projectUnit: projectUnit)
        ReputationDetailsFetchMock.register(mock: .success, projectUnit: projectUnit)

        let viewModelFactory = ReputationViewModelFactory(timeFormatter: TotalTimeFormatter())
        let presenter = ReputationPresenter(viewModelFactory: viewModelFactory,
                                            reputationDelayFactory: ReputationDelayFactory(),
                                            votesFormatter: NumberFormatter.vote,
                                            integerFormatter: NumberFormatter.anyInteger)
        let view = MockReputationViewProtocol()
        let wireframe = MockReputationWireframeProtocol()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let reputationExpectation = XCTestExpectation()
        let votesExpectation = XCTestExpectation()
        let reputationDetailsExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).set(reputationDetailsViewModel: any(ReputationDetailsViewModel.self))
                .then { _ in
                    reputationDetailsExpectation.fulfill()
            }

            when(stub).set(votesDetails: any(String.self)).then { _ in
                votesExpectation.fulfill()
            }

            when(stub).set(existingRankDetails: any(String.self)).then { _ in
                reputationExpectation.fulfill()
            }
        }

        // when

        presenter.viewIsReady()

        // then

        wait(for: [reputationExpectation, votesExpectation, reputationDetailsExpectation],
             timeout: Constants.networkRequestTimeout)
    }

    func testEmptyRankAndThenNormal() {
        // given
        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsReputationFetchMock.register(mock: .nullSuccess, projectUnit: projectUnit)
        ProjectsVotesCountMock.register(mock: .success, projectUnit: projectUnit)
        ReputationDetailsFetchMock.register(mock: .success, projectUnit: projectUnit)

        let viewModelFactory = ReputationViewModelFactory(timeFormatter: TotalTimeFormatter())
        let reputationDelayFactory = MockReputationDelayFactoryProtocol()
        let presenter = ReputationPresenter(viewModelFactory: viewModelFactory,
                                            reputationDelayFactory: reputationDelayFactory,
                                            votesFormatter: NumberFormatter.vote,
                                            integerFormatter: NumberFormatter.anyInteger)
        let view = MockReputationViewProtocol()
        let wireframe = MockReputationWireframeProtocol()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let reputationExpectation = XCTestExpectation()
        let votesExpectation = XCTestExpectation()
        let reputationDetailsExpectation = XCTestExpectation()

        let reputationDelay: TimeInterval = 2.0

        stub(view) { stub in
            when(stub).set(reputationDetailsViewModel: any(ReputationDetailsViewModel.self))
                .then { _ in
                    reputationDetailsExpectation.fulfill()
            }

            when(stub).set(votesDetails: any(String.self)).then { _ in
                votesExpectation.fulfill()
            }

            when(stub).set(emptyRankDetails: any(String.self)).then { _ in
                reputationExpectation.fulfill()
            }
        }

        stub(reputationDelayFactory) { stub in
            when(stub).calculateDelay(from: any(Date.self)).then { _ in
                return reputationDelay
            }
        }

        // when

        presenter.viewIsReady()

        // then

        wait(for: [reputationExpectation, votesExpectation, reputationDetailsExpectation],
             timeout: Constants.networkRequestTimeout)

        // when

        ProjectsReputationFetchMock.register(mock: .success, projectUnit: projectUnit)

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).set(existingRankDetails: any(String.self)).then { _ in
                completionExpectation.fulfill()
            }
        }

        // then

        wait(for: [completionExpectation], timeout: Constants.networkRequestTimeout)
    }
}
