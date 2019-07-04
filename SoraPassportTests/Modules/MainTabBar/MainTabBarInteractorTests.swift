/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo

class MainTabBarInteractorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testNotificationRegistrationWhenViewBecomesReady() {
        // given
        let view = MockMainTabBarViewProtocol()
        let wireframe = MockMainTabBarWireframeProtocol()

        let presenter = MainTabBarPresenter()
        presenter.view = view
        presenter.wireframe = wireframe

        let applicationConfig = MockApplicationConfigProtocol()
        let notificationRegistration = MockNotificationsRegistrationProtocol()

        let interactor = MainTabBarInteractor(applicationConfig: applicationConfig,
                                              notificationRegistrator: notificationRegistration)

        presenter.interactor = interactor
        interactor.presenter = presenter

        let notificationOptions = NotificationsOptions.alert.union(.badge).union(.sound)

        stub(applicationConfig) { stub in
            when(stub.notificationOptions).get.then {
                notificationOptions.rawValue
            }
        }

        stub(notificationRegistration) { stub in
            when(stub.registerNotifications(options: any(NotificationsOptions.self))).thenDoNothing()
            when(stub.registerForRemoteNotifications()).thenDoNothing()
        }

        // when
        presenter.viewIsReady()

        // then
        verify(notificationRegistration, times(1)).registerForRemoteNotifications()
    }
}
