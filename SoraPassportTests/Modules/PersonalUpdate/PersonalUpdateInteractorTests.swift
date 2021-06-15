import XCTest
import Cuckoo
import RobinHood
import SoraKeystore
import SoraFoundation
@testable import SoraPassport

class PersonalUpdateInteractorTests: NetworkBaseTests {

    func testSuccessfullSetupAndUpdate() {
        // given
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

        XCTAssertNotNil(presenter.username)

        // when
        let randomUser = createRandomUser()

        presenter.models?[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler
            .changeValue(to: randomUser.username ?? "")

        presenter.save()

        // then

        verify(mockView, times(1)).didCompleteSaving(success: true)
    }

    func testSetupFailed() {
        // given
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
        }

        mockWireframe.errorPresentationCalledBlock = {
            setupExpectation.fulfill()
        }

        // when

        presenter.setup()

        // then

        XCTAssertEqual(mockWireframe.numberOfCloseCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfAlertPresentationCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfErrorPresentationCalled, 0)
    }

    func testUpdateFailed() {
        // given
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

            when(stub).didStartSaving().thenDoNothing()

            when(stub).didCompleteSaving(success: true).then { _ in
                updateExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        XCTAssertNotNil(presenter.username)

        let randomUser = createRandomUser()

        presenter.models?[PersonalUpdatePresenter.ViewModelIndex.userName.rawValue].inputHandler
            .changeValue(to: randomUser.username ?? "")

        presenter.save()

        // then

        XCTAssertEqual(mockWireframe.numberOfCloseCalled, 1)
        XCTAssertEqual(mockWireframe.numberOfAlertPresentationCalled, 0)
        XCTAssertEqual(mockWireframe.numberOfErrorPresentationCalled, 0)
    }

    // MARK: Private
    private func createPresenter() -> PersonalUpdatePresenter {
        let factory = PersonalInfoViewModelFactory()
        return PersonalUpdatePresenter(viewModelFactory: factory)
    }

    private func createInteractor() -> PersonalUpdateInteractor {
        var inMemorySettingsManager = InMemorySettingsManager()
        inMemorySettingsManager.selectedAccount = AccountItem(address: "5G71rM4RwZehaHsGNXc6FMjZoWJRCooMWARHY6YU2WDpNgpA",
                                                               cryptoType: .sr25519,
                                                               username: "test user",
                                                               publicKeyData: Data())
        return PersonalUpdateInteractor(settingsManager: inMemorySettingsManager)
    }
}
