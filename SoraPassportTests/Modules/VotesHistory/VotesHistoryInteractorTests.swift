/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class VotesHistoryInteractorTests: NetworkBaseTests {
    func testSuccessFullSetupAndFirstPageLoading() {
        // given
        VotesHistoryFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interator = createInteractor()
        let presenter = createPresenter()
        let viewMock = MockVotesHistoryViewProtocol()

        interator.presenter = presenter
        presenter.view = viewMock
        presenter.interactor = interator

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        stub(viewMock) { (stub) in
            when(stub).didReload().then { _ in
                expectation.fulfill()
            }
        }

        // when
        presenter.viewIsReady()

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

        verify(viewMock, times(2)).didReload()
    }

    // MARK: Private

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
        let dateFormatterBuilder = CompoundDateFormatterBuilder()
        let votesHistoryDateFormatter = dateFormatterBuilder
            .withToday(title: R.string.localizable.today())
            .withYesterday(title: R.string.localizable.yesterday())
            .withThisYear(dateFormatter: DateFormatter.sectionThisYear)
            .build(defaultFormat: R.string.localizable.anyYearFormat())

        let votesHistoryViewModelFactory = VotesHistoryViewModelFactory(dateFormatter: votesHistoryDateFormatter,
                                                                        amountFormatter: NumberFormatter.vote)

        return VotesHistoryPresenter(viewModelFactory: votesHistoryViewModelFactory)
    }
}
