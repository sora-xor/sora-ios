import XCTest
@testable import SoraPassport
import Cuckoo
import SoraFoundation

class InvitationHandlePresenterTests: NetworkBaseTests {
/*
    func testDeepLinkHandlingSuccess() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithoutParent, projectUnit: projectUnit)
        ApplyInvitationMock.register(mock: .success, projectUnit: projectUnit)

        let eventCenter = EventCenter()
        let wireframe = MockInvitationHandleWireframeProtocol()
        let presenter = createPresenter(for: wireframe, eventCenter: eventCenter)

        // when

        let alertExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(message: any(), title: any(), actions: any(), from: any()).then { _, _, actions, _ in
                actions.last?.handler?()
            }

            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                alertExpectation.fulfill()
            }
        }

        let invitationAppliedExpectation = XCTestExpectation()

        let observer = MockEventVisitorProtocol()
        stub(observer) { stub in
            when(stub).processInvitationApplied(event: any()).then { _ in
                invitationAppliedExpectation.fulfill()
            }
        }

        eventCenter.add(observer: observer, dispatchIn: nil)

        presenter.setup()
        XCTAssertTrue(presenter.navigate(to: InvitationDeepLink(code: Constants.dummyInvitationCode)))

        // then

        wait(for: [alertExpectation, invitationAppliedExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNil(presenter.pendingInvitationCode)
    }

    func testInvitationApplicationSuccess() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithoutParent, projectUnit: projectUnit)
        ApplyInvitationMock.register(mock: .success, projectUnit: projectUnit)

        let eventCenter = EventCenter()
        let wireframe = MockInvitationHandleWireframeProtocol()
        let presenter = createPresenter(for: wireframe, eventCenter: eventCenter)

        // when

        let alertExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                alertExpectation.fulfill()
            }
        }

        let invitationAppliedExpectation = XCTestExpectation()

        let observer = MockEventVisitorProtocol()
        stub(observer) { stub in
            when(stub).processInvitationApplied(event: any()).then { _ in
                invitationAppliedExpectation.fulfill()
            }

            when(stub).processInvitationInput(event: any()).thenDoNothing()
        }

        eventCenter.add(observer: observer, dispatchIn: nil)

        presenter.setup()

        eventCenter.notify(with: InvitationInputEvent(code: Constants.dummyInvitationCode))

        // then

        wait(for: [alertExpectation, invitationAppliedExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNil(presenter.pendingInvitationCode)
    }

    func testInvitationApplicationCodeNotFound() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithoutParent, projectUnit: projectUnit)
        ApplyInvitationMock.register(mock: .notFound, projectUnit: projectUnit)

        let eventCenter = EventCenter()
        let wireframe = MockInvitationHandleWireframeProtocol()
        let presenter = createPresenter(for: wireframe, eventCenter: eventCenter)

        // when

        let alertExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(error: any(), from: any(), locale: any()).then { error, _, _ in
                guard
                    let applyDataError = error as? ApplyInvitationDataError,
                    applyDataError == .codeNotFound else {
                    XCTFail("Invalid error")
                    return false
                }

                alertExpectation.fulfill()
                return true
            }
        }

        presenter.setup()

        eventCenter.notify(with: InvitationInputEvent(code: Constants.dummyInvitationCode))

        // then

        wait(for: [alertExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNil(presenter.pendingInvitationCode)
    }

    // MARK: Private

    private func createPresenter(for wireframe: MockInvitationHandleWireframeProtocol, eventCenter: EventCenterProtocol) -> InvitationHandlePresenter {
        let mockedRequestSigner = createDummyRequestSigner()

        let localizationManager = LocalizationManager(localization: Constants.englishLocalization)!

        let presenter = InvitationHandlePresenter(localizationManager: localizationManager)

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = mockedRequestSigner

        let coreDataFacade = CoreDataCacheTestFacade()
        let customerFacade = CustomerDataProviderFacade()
        customerFacade.coreDataCacheFacade = coreDataFacade
        customerFacade.requestSigner = mockedRequestSigner

        let interactor = InvitationHandleInteractor(projectService: projectService,
                                                    userDataProvider: customerFacade.userProvider,
                                                    eventCenter: eventCenter)

        let view = MockControllerBackedProtocol()

        stub(view) { stub in
            when(stub).controller.get.thenReturn(UIViewController())
        }

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return presenter
    }
 */
}
