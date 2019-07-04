/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class HelpInteractorTests: NetworkBaseTests {

    func testSuccessfullSetup() {
        // given
        HelpFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interactor = createInteractor()
        let presenter = createPresenter()
        let view = MockHelpViewProtocol()
        let wireframe = MockHelpWireframeProtocol()

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let dataExpectation = XCTestExpectation()
        dataExpectation.expectedFulfillmentCount = 2
        dataExpectation.assertForOverFulfill = false

        let supportExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didLoad(viewModels: any([HelpViewModelProtocol].self)).then { _ in
                dataExpectation.fulfill()
            }

            when(stub).didReceive(supportItem: any(PosterViewModelProtocol.self)).then { _ in
                supportExpectation.fulfill()
            }

            when(stub).leadingItemLayoutMetadata.get.thenReturn(HelpItemLayoutMetadata())
            when(stub).normalItemLayoutMetadata.get.thenReturn(HelpItemLayoutMetadata())
            when(stub).supportLayoutMetadata.get.thenReturn(SupportViewFactory.createLayoutMetadata(from: .zero, preferredWidth: 375.0))
        }

        // when

        presenter.viewIsReady()

        wait(for: [dataExpectation, supportExpectation], timeout: Constants.expectationDuration)

        // then

        verify(view, atLeast(2)).didLoad(viewModels: any([HelpViewModelProtocol].self))
        verify(view, times(1)).didReceive(supportItem: any(PosterViewModelProtocol.self))
    }

    // MARK: Private

    private func createInteractor() -> HelpInteractor {
        let requestSigner = createDummyRequestSigner()

        let informationFacade = InformationDataProviderFacade()
        informationFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        informationFacade.requestSigner = requestSigner

        return HelpInteractor(helpDataProvider: informationFacade.helpDataProvider)
    }

    private func createPresenter() -> HelpPresenter {
        let supportData = SupportData(title: "",
                                      subject: "",
                                      details: "",
                                      email: "")

        let supportViewModelFactory = PosterViewModelFactory()

        let helpViewModelFactory = HelpViewModelFactory()

        return HelpPresenter(helpViewModelFactory: helpViewModelFactory,
                             supportViewModelFactory: supportViewModelFactory,
                             supportData: supportData)
    }
}
