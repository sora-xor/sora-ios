import XCTest
@testable import SoraPassport
//import SoraCrypto
import Cuckoo

class NotificationInteractorTests: NetworkBaseTests {
/*
    func testNotificationsSetupSuccessWhenUserRegistered() {
        // given
        NotificationTokenExchangeMock.register(mock: .success, notificationUnit: ApplicationConfig.shared.defaultNotificationUnit)
        NotificationEnablePermissionMock.register(mock: .success, notificationUnit: ApplicationConfig.shared.defaultNotificationUnit)

        let finishExpectation = XCTestExpectation()

        let presenter = MockNotificationsInteractorOutputProtocol()

        let eventCenter: EventCenterProtocol = MockEventCenterProtocol()

        stub(presenter) { (stub) in
            when(stub.didCompleteNotificationsSetup()).then {
                finishExpectation.fulfill()
            }

            when(stub.didReceiveNotificationsSetup(error: any(Error.self))).thenDoNothing()
            when(stub.didReceive(any())).thenReturn(true)
        }

        let interator = createInteractor(with: presenter, eventCenter: eventCenter)

        // when
        interator.didReceive(remoteToken: Constants.dummyPushToken)

        // then
        wait(for: [finishExpectation], timeout: Constants.expectationDuration)
    }

    func testNotificationsSetupSuccessWhenUserNotRegistered() {
        // given
        NotificationTokenExchangeMock.register(mock: .userNotFound, notificationUnit: ApplicationConfig.shared.defaultNotificationUnit)
        NotificationRegisterMock.register(mock: .success, notificationUnit: ApplicationConfig.shared.defaultNotificationUnit)

        let finishExpectation = XCTestExpectation()

        let presenter = MockNotificationsInteractorOutputProtocol()

        let eventCenter: EventCenterProtocol = MockEventCenterProtocol()

        stub(presenter) { (stub) in
            when(stub.didCompleteNotificationsSetup()).then {
                finishExpectation.fulfill()
            }

            when(stub.didReceiveNotificationsSetup(error: any(Error.self))).thenDoNothing()
            when(stub.didReceive(any())).thenReturn(true)
        }

        let interactor = createInteractor(with: presenter, eventCenter: eventCenter)

        // when
        interactor.didReceive(remoteToken: Constants.dummyPushToken)

        // then
        wait(for: [finishExpectation], timeout: Constants.expectationDuration)
    }

    func testEventCenterNotifiedWhenNotificationReceived() {
        // given

        let presenter: MockNotificationsInteractorOutputProtocol = MockNotificationsInteractorOutputProtocol()
        let eventCenter = MockEventCenterProtocol()

        stub(presenter) { stub in
            when(stub).didReceive(any()).thenReturn(true)
        }

        stub(eventCenter) { stub in
            when(stub).notify(with: any()).thenDoNothing()
        }

        let interactor = createInteractor(with: presenter, eventCenter: eventCenter)

        // when

        let expectedNotification = SoraNotification(title: UUID().uuidString, body: UUID().uuidString)

        XCTAssertTrue(interactor.didReceive(expectedNotification))

        // then

        let parameterMatcher = ParameterMatcher { (event: EventProtocol) in
            guard let pushEvent = event as? PushNotificationEvent else {
                return false
            }

            guard let notification = pushEvent.notification as? SoraNotification else {
                return false
            }

            return notification == expectedNotification
        }

        verify(eventCenter, times(1)).notify(with: parameterMatcher)
    }

    // MARK: Private

    private func createInteractor(with presenter: NotificationsInteractorOutputProtocol,
                                  eventCenter: EventCenterProtocol) -> NotificationsServiceOutputProtocol {
        let notificationService = NotificationUnitService(unit: ApplicationConfig.shared.defaultNotificationUnit,
                                                          requestSigner: createDummyRequestSigner())

        let interactor = NotificationsInteractor(presenter: presenter,
                                                 eventCenter: eventCenter,
                                                 config: ApplicationConfig.shared,
                                                 notificationUnitService: notificationService,
                                                 notificationsRegistrator: NotificationsRegistration())

        return interactor
    }
 */
}
