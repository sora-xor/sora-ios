/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class ActivityFeedInteractorTests: NetworkBaseTests {

    func testSuccessfullSetupAndFirstPageLoading() {
        // given
        ActivityFeedMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        ProjectsFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        AnnouncementFetchMock.register(mock: .successNotEmpty,
                                       projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        CurrencyFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interactor = createInteractor()
        let presenter = createPresenter()
        let viewMock = MockActivityFeedViewProtocol()

        interactor.presenter = presenter
        presenter.view = viewMock
        presenter.wireframe = MockActivityFeedWireframeProtocol()
        presenter.interactor = interactor

        let itemsExpectation = XCTestExpectation()
        itemsExpectation.expectedFulfillmentCount = 2
        itemsExpectation.assertForOverFulfill = false

        let announcementExpectation = XCTestExpectation()
        announcementExpectation.expectedFulfillmentCount = 2
        announcementExpectation.assertForOverFulfill = false

        stub(viewMock) { (stub) in
            when(stub).didReceive(using: any((() -> [ActivityFeedViewModelChange]).self)).then { _ in
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
        }

        // when
        presenter.viewIsReady()

        // then

        guard case .waitingCached = presenter.dataLoadingState else {
            XCTFail()
            return
        }

        wait(for: [itemsExpectation, announcementExpectation],
             timeout: Constants.networkRequestTimeout)

        guard case .loaded(let page, _) = presenter.dataLoadingState, page == 0 else {
            XCTFail()
            return
        }

        verify(viewMock, times(2)).didReceive(using: any((() -> [ActivityFeedViewModelChange]).self))
        verify(viewMock, atLeast(2)).didReload(announcement: any(AnnouncementItemViewModelProtocol?.self))
    }

    // MARK: Private

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
        let activityFeedViewModelFactory = ActivityFeedViewFactory.createActivityFeedItemViewModelFactory()
        let announcementViewModelFactory = AnnouncementViewModelFactory()

        return ActivityFeedPresenter(itemViewModelFactory: activityFeedViewModelFactory,
                                     announcementViewModelFactory: announcementViewModelFactory)
    }
}
