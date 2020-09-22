import XCTest
@testable import SoraPassport
import Cuckoo

class InvitationInteractorTests: NetworkBaseTests {

    func testInvitationSharingSuccessWhenParentExists() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)
        ProjectsInvitedMock.register(mock: .successWithParent, projectUnit: projectUnit)

        // when

        let finalViewModel = performInvitationSendTest()

        // then

        guard let actionViewModel = finalViewModel else {
            XCTFail("Unexpected empty invitation action view model")
            return
        }

        XCTAssertNotNil(actionViewModel.headerText)
        XCTAssertNotNil(actionViewModel.footerText)
        XCTAssertEqual(actionViewModel.actions.count, 1)
    }

    func testInvitationSharingSuccessWhenParentMomentExpired() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithExpiredParentMoment, projectUnit: projectUnit)
        ProjectsInvitedMock.register(mock: .successWithoutParent, projectUnit: projectUnit)

        // when

        let finalViewModel = performInvitationSendTest()

        // then

        guard let actionViewModel = finalViewModel else {
            XCTFail("Unexpected empty invitation action view model")
            return
        }

        XCTAssertNotNil(actionViewModel.headerText)
        XCTAssertNil(actionViewModel.footerText)
        XCTAssertEqual(actionViewModel.actions.count, 1)
    }

    func testInvitationSharingSuccessWhenParentMomentNotExpired() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithoutParent, projectUnit: projectUnit)
        ProjectsInvitedMock.register(mock: .successWithoutParent, projectUnit: projectUnit)

        // when

        let finalViewModel = performInvitationSendTest()

        // then

        guard let actionViewModel = finalViewModel else {
            XCTFail("Unexpected empty invitation action view model")
            return
        }

        XCTAssertNotNil(actionViewModel.headerText)
        XCTAssertNotNil(actionViewModel.footerText)
        XCTAssertEqual(actionViewModel.actions.count, 2)
    }

    func testParentAddSuccess() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsCustomerMock.register(mock: .successWithoutParent, projectUnit: projectUnit)
        ProjectsInvitedMock.register(mock: .successWithoutParent, projectUnit: projectUnit)

        let eventCenter = MockEventCenterProtocol()
        let view = MockInvitationViewProtocol()
        let wireframe = MockInvitationWireframeProtocol()

        let presenter = createPresenter(from: view, wireframe: wireframe, eventCenter: eventCenter)

        // when

        let inputCompleteExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
            when(stub).notify(with: any()).then { event in
                if event is InvitationInputEvent {
                    inputCompleteExpectation.fulfill()
                }
            }
        }

        let actionViewModelExpectation = XCTestExpectation()
        actionViewModelExpectation.expectedFulfillmentCount = 3

        let invitedListExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(actionListViewModel: any(InvitationActionListViewModel.self))
                .then { viewModel in
                actionViewModelExpectation.fulfill()
            }

            when(stub).didReceive(invitedUsers: any([InvitedViewModelProtocol].self)).then { _ in
                invitedListExpectation.fulfill()
            }

            when(stub).didChange(actionStyle: any(), at: any()).thenDoNothing()
            when(stub).didChange(accessoryTitle: any(), at: any()).thenDoNothing()
        }

        presenter.setup(with: .default)
        presenter.viewDidAppear()

        // then

        wait(for: [actionViewModelExpectation, invitedListExpectation],
             timeout: Constants.networkRequestTimeout)

        // when

        var inputViewModel: InputFieldViewModelProtocol?

        stub(wireframe) { stub in
            when(stub).requestInput(for: any(), from: any()).then { viewModel, _ in
                inputViewModel = viewModel
                let result = viewModel.didReceive(replacement: Constants.dummyInvitationCode,
                                                  in: NSRange(location: 0, length: 0))
                XCTAssertTrue(result)
            }
        }

        presenter.didSelectAction(at: InvitationPresenter.InvitationActionType.enterCode.rawValue)

        guard let invitationViewModel = inputViewModel else {
            XCTFail("Unexpected nil view model")
            return
        }

        presenter.inputFieldDidCompleteInput(to: invitationViewModel)

        // then

        wait(for: [inputCompleteExpectation], timeout: Constants.networkRequestTimeout)
    }

    private func performInvitationSendTest() -> InvitationActionListViewModel? {
        // given

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let view = MockInvitationViewProtocol()
        let wireframe = MockInvitationWireframeProtocol()
        let presenter = createPresenter(from: view,
                                        wireframe: wireframe,
                                        eventCenter: eventCenter)

        // when

        var finalViewModel: InvitationActionListViewModel?

        let actionViewModelExpectation = XCTestExpectation()
        actionViewModelExpectation.expectedFulfillmentCount = 3

        let invitedListExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(actionListViewModel: any(InvitationActionListViewModel.self))
                .then { viewModel in
                finalViewModel = viewModel
                actionViewModelExpectation.fulfill()
            }

            when(stub).didReceive(invitedUsers: any([InvitedViewModelProtocol].self)).then { _ in
                invitedListExpectation.fulfill()
            }

            when(stub).didChange(actionStyle: any(), at: any()).thenDoNothing()
            when(stub).didChange(accessoryTitle: any(), at: any()).thenDoNothing()
        }

        let sharingExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).share(source: any(), from: any(), with: any()).then { _ in
                sharingExpectation.fulfill()
            }
        }

        presenter.setup(with: .default)
        presenter.viewDidAppear()

        // then

        wait(for: [actionViewModelExpectation, invitedListExpectation],
             timeout: Constants.networkRequestTimeout)

        // when

        presenter.didSelectAction(at: InvitationPresenter.InvitationActionType.sendInvite.rawValue)

        // then

        wait(for: [sharingExpectation], timeout: Constants.networkRequestTimeout)

        verify(eventCenter, times(1)).add(observer: any(), dispatchIn: any())

        return finalViewModel
    }

    private func createPresenter(from view: MockInvitationViewProtocol,
                                 wireframe: MockInvitationWireframeProtocol,
                                 eventCenter: EventCenterProtocol) -> InvitationPresenter {
        let mockedRequestSigner = createDummyRequestSigner()
        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)

        let integerFormatter = NumberFormatter.anyInteger.localizableResource()
        let invitationViewModelFactory = InvitationViewModelFactory(integerFormatter: integerFormatter)
        let timerFactory = CountdownTimerFactory()

        let presenter = InvitationPresenter(invitationViewModelFactory: invitationViewModelFactory,
                                            timerFactory: timerFactory,
                                            invitationFactory: invitationFactory)

        let coreDataFacade = CoreDataCacheTestFacade()
        let customerFacade = CustomerDataProviderFacade()
        customerFacade.coreDataCacheFacade = coreDataFacade
        customerFacade.requestSigner = mockedRequestSigner

        let interactor = InvitationInteractor(customerDataProviderFacade: customerFacade,
                                              eventCenter: eventCenter)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
