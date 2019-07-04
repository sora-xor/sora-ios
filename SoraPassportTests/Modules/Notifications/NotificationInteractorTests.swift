/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport
import SoraCrypto
import Cuckoo

class NotificationInteractorTests: NetworkBaseTests {

    func testNotificationsSetupSuccessWhenUserRegistered() {
        // given
        NotificationTokenExchangeMock.register(mock: .success, notificationUnit: ApplicationConfig.shared.defaultNotificationUnit)
        NotificationEnablePermissionMock.register(mock: .success, notificationUnit: ApplicationConfig.shared.defaultNotificationUnit)

        let finishExpectation = XCTestExpectation()

        let presenter = MockNotificationsInteractorOutputProtocol()

        stub(presenter) { (stub) in
            when(stub.didCompleteNotificationsSetup()).then {
                finishExpectation.fulfill()
            }

            when(stub.didReceiveNotificationsSetup(error: any(Error.self))).thenDoNothing()
            when(stub.didReceive(any())).thenDoNothing()
        }

        let interator = createInteractor(with: presenter)

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

        stub(presenter) { (stub) in
            when(stub.didCompleteNotificationsSetup()).then {
                finishExpectation.fulfill()
            }

            when(stub.didReceiveNotificationsSetup(error: any(Error.self))).thenDoNothing()
            when(stub.didReceive(any())).thenDoNothing()
        }

        let interactor = createInteractor(with: presenter)

        // when
        interactor.didReceive(remoteToken: Constants.dummyPushToken)

        // then
        wait(for: [finishExpectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private

    private func createInteractor(with presenter: NotificationsInteractorOutputProtocol) -> NotificationsServiceOutputProtocol {
        let notificationService = NotificationUnitService(unit: ApplicationConfig.shared.defaultNotificationUnit,
                                                          requestSigner: createDummyRequestSigner())

        let interactor = NotificationsInteractor(presenter: presenter,
                                                 config: ApplicationConfig.shared,
                                                 notificationUnitService: notificationService,
                                                 notificationsRegistrator: NotificationsRegistration(),
                                                 notificationsLocalScheduler: NotificationsLocalScheduler())

        return interactor
    }
}
