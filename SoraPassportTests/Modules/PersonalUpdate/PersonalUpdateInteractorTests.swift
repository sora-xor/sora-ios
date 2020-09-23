/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import SoraPassport

class PersonalUpdateInteractorTests: NetworkBaseTests {

    func testSuccessfullSetupAndUpdate() {
        // given
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        UpdateCustomerMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let presenter = createPresenter()
        let interactor = createInteractor()
        interactor.presenter = presenter
        presenter.interactor = interactor

        let mockView = MockPersonalUpdateViewProtocol()
        let mockWireframe = MockPersonalUpdateWireframeProtocol()

        presenter.view = mockView
        presenter.wireframe = mockWireframe

        let setupExpectation = XCTestExpectation()
        setupExpectation.expectedFulfillmentCount = 2

        let updateExpectation = XCTestExpectation()

        stub(mockView) { stub in
            when(stub).didReceive(viewModels: any([InputViewModelProtocol].self)).then { _ in
                setupExpectation.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
            when(stub).didStartSaving().thenDoNothing()

            when(stub).didCompleteSaving(success: true).then { _ in
                updateExpectation.fulfill()
            }
        }

        stub(mockWireframe) { stub in
            when(stub).close(view: any()).thenDoNothing()
        }

        // when
        presenter.setup()

        // then
        XCTAssertTrue(presenter.dataLoadingState == .waitingCached)

        wait(for: [setupExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNotNil(presenter.userData)
        XCTAssertTrue(presenter.dataLoadingState == .refreshed)

        // when
        let personalUpdateInfo = createRandomPersonalUpdateInfo()

        presenter.models?[PersonalUpdatePresenter.ViewModelIndex.firstName.rawValue].inputHandler
            .changeValue(to: personalUpdateInfo.firstName ?? "")
        presenter.models?[PersonalUpdatePresenter.ViewModelIndex.lastName.rawValue].inputHandler
            .changeValue(to: personalUpdateInfo.lastName ?? "")

        presenter.save()

        wait(for: [updateExpectation], timeout: Constants.networkRequestTimeout)

        // then

        verify(mockView, times(1)).didCompleteSaving(success: true)
    }

    func testSetupFailed() {
        // given
        ProjectsCustomerMock.register(mock: .resourceNotFound,
                                      projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let presenter = createPresenter()
        let interactor = createInteractor()
        interactor.presenter = presenter
        presenter.interactor = interactor

        let mockView = MockPersonalUpdateViewProtocol()
        let mockWireframe = PersonalUpdateWireframeMock()

        presenter.view = mockView
        presenter.wireframe = mockWireframe

        let setupExpectation = XCTestExpectation()

        stub(mockView) { stub in
            when(stub).didReceive(viewModels: any([InputViewModelProtocol].self)).thenDoNothing()
            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
        }

        mockWireframe.errorPresentationCalledBlock = {
            setupExpectation.fulfill()
        }

        // when

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertTrue(presenter.dataLoadingState == .waitingRefresh)
        XCTAssertEqual(mockWireframe.numberOfCloseCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfAlertPresentationCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfErrorPresentationCalled, 1)
    }

    func testUpdateFailed() {
        // given
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        UpdateCustomerMock.register(mock: .resourceNotFound, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let presenter = createPresenter()
        let interactor = createInteractor()
        interactor.presenter = presenter
        presenter.interactor = interactor

        let mockView = MockPersonalUpdateViewProtocol()
        let mockWireframe = PersonalUpdateWireframeMock()

        presenter.view = mockView
        presenter.wireframe = mockWireframe

        let setupExpectation = XCTestExpectation()
        setupExpectation.expectedFulfillmentCount = 2

        let updateExpectation = XCTestExpectation()

        stub(mockView) { stub in
            when(stub).didReceive(viewModels: any([InputViewModelProtocol].self)).then { _ in
                setupExpectation.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
            when(stub).didStartSaving().thenDoNothing()

            when(stub).didCompleteSaving(success: false).then { _ in
                updateExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.networkRequestTimeout)

        let personalUpdateInfo = createRandomPersonalUpdateInfo()

        XCTAssertNotNil(presenter.userData)

        presenter.models?[PersonalUpdatePresenter.ViewModelIndex.firstName.rawValue].inputHandler
            .changeValue(to: personalUpdateInfo.firstName ?? "")
        presenter.models?[PersonalUpdatePresenter.ViewModelIndex.lastName.rawValue].inputHandler
            .changeValue(to: personalUpdateInfo.lastName ?? "")

        presenter.save()

        wait(for: [updateExpectation], timeout: Constants.networkRequestTimeout)

        // then

        XCTAssertEqual(mockWireframe.numberOfCloseCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfAlertPresentationCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfErrorPresentationCalled, 1)
    }

    // MARK: Private
    private func createPresenter() -> PersonalUpdatePresenter {
        let factory = PersonalInfoViewModelFactory()
        return PersonalUpdatePresenter(locale: Locale.current, viewModelFactory: factory)
    }

    private func createInteractor() -> PersonalUpdateInteractor {
        let requestSigner = createDummyRequestSigner()

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        let customerFacade = CustomerDataProviderFacade()
        customerFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        customerFacade.requestSigner = requestSigner

        return PersonalUpdateInteractor(customerFacade: customerFacade,
                                        projectService: projectService)
    }
}
