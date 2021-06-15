import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import IrohaCrypto
import SoraFoundation

class MainTabBarInteractorTests: NetworkBaseTests {
    /*
    func testNotificationRegistrationWhenViewBecomesReady() {
        // given
        let view = MockMainTabBarViewProtocol()
        let wireframe = MockMainTabBarWireframeProtocol()

        let presenter = MainTabBarPresenter(children: [])
        presenter.view = view
        presenter.wireframe = wireframe

        let applicationConfig = MockApplicationConfigProtocol()
        let notificationRegistration = MockNotificationsRegistrationProtocol()

        let settings = InMemorySettingsManager()

        let eventCenter = MockEventCenterProtocol()
        let applicationHandler = MockApplicationHandlerProtocol()

        let dataStreamService = MockDataStreamServiceProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        stub(applicationHandler) { stub in
            when(stub).delegate.get.thenReturn(nil)
            when(stub).delegate.set(any()).thenDoNothing()
        }

        stub(dataStreamService) { stub in
            when(stub).setup().thenDoNothing()
            when(stub).throttle().thenDoNothing()
        }

        let interactor = MainTabBarInteractor(eventCenter: eventCenter,
                                              settings: settings,
                                              applicationConfig: applicationConfig,
                                              applicationHandler: applicationHandler,
                                              notificationRegistrator: notificationRegistration,
                                              invitationLinkService: InvitationLinkService(settings: settings),
                                              walletContext: WalletContextMock(),
                                              userServices: [dataStreamService])

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
        presenter.setup()

        // then
        verify(notificationRegistration, times(1)).registerForRemoteNotifications()
        verify(dataStreamService, times(1)).setup()
    }

    func testDeepLinkHandling() {
        // given

        let view = MockMainTabBarViewProtocol()
        let wireframe = MockMainTabBarWireframeProtocol()

        let mockInvitationHandler = MockInvitationHandlePresenterProtocol()

        let presenter = MainTabBarPresenter(children: [mockInvitationHandler])
        presenter.view = view
        presenter.wireframe = wireframe

        let applicationConfig = MockApplicationConfigProtocol()
        let notificationRegistration = MockNotificationsRegistrationProtocol()

        let settings = InMemorySettingsManager()

        let eventCenter = MockEventCenterProtocol()
        let applicationHandler = MockApplicationHandlerProtocol()

        let dataStreamService = MockDataStreamServiceProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        stub(applicationHandler) { stub in
            when(stub).delegate.get.thenReturn(nil)
            when(stub).delegate.set(any()).thenDoNothing()
        }

        stub(dataStreamService) { stub in
            when(stub).setup().thenDoNothing()
            when(stub).throttle().thenDoNothing()
        }

        let interactor = MainTabBarInteractor(eventCenter: eventCenter,
                                              settings: settings,
                                              applicationConfig: applicationConfig,
                                              applicationHandler: applicationHandler,
                                              notificationRegistrator: notificationRegistration,
                                              invitationLinkService: InvitationLinkService(settings: settings),
                                              walletContext: WalletContextMock(),
                                              userServices: [dataStreamService])

        presenter.interactor = interactor
        interactor.presenter = presenter

        stub(mockInvitationHandler) { stub in
            when(stub).navigate(to: any(InvitationDeepLink.self)).thenReturn(true)
        }

        // when

        presenter.viewDidAppear()

        XCTAssert(interactor.invitationLinkService.handle(url: Constants.dummyInvitationLink))

        // then

        XCTAssertNil(interactor.invitationLinkService.link)
        XCTAssertNil(settings.invitationCode)

        verify(mockInvitationHandler, times(1)).navigate(to: any(InvitationDeepLink.self))
    }

    func testWalletAccountUpdatesWhenNotificationReceived() {
        // given
        let view = MockMainTabBarViewProtocol()
        let wireframe = MockMainTabBarWireframeProtocol()

        let presenter = MainTabBarPresenter(children: [])
        presenter.view = view
        presenter.wireframe = wireframe

        let applicationConfig = MockApplicationConfigProtocol()
        let notificationRegistration = MockNotificationsRegistrationProtocol()

        let settings = InMemorySettingsManager()

        let eventCenter = EventCenter()
        let applicationHandler = MockApplicationHandlerProtocol()

        let walletContext = WalletContextMock()

        let dataStreamService = MockDataStreamServiceProtocol()

        stub(applicationHandler) { stub in
            when(stub).delegate.get.thenReturn(nil)
            when(stub).delegate.set(any()).thenDoNothing()
        }

        stub(dataStreamService) { stub in
            when(stub).setup().thenDoNothing()
            when(stub).throttle().thenDoNothing()
        }

        let interactor = MainTabBarInteractor(eventCenter: eventCenter,
                                              settings: settings,
                                              applicationConfig: applicationConfig,
                                              applicationHandler: applicationHandler,
                                              notificationRegistrator: notificationRegistration,
                                              invitationLinkService: InvitationLinkService(settings: settings),
                                              walletContext: walletContext,
                                              userServices: [dataStreamService])

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

        let finishExpectation = XCTestExpectation()

        walletContext.closurePrepareAccountUpdateCommand = {
            finishExpectation.fulfill()

            return WalletCommandMock()
        }

        // when
        presenter.setup()

        eventCenter.notify(with: PushNotificationEvent(notification: SoraNotification(title: nil, body: nil)))

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)
    }

    func testWalletAccountUpdatesWhenRestoreFromBackground() {
        // given
        let view = MockMainTabBarViewProtocol()
        let wireframe = MockMainTabBarWireframeProtocol()

        let presenter = MainTabBarPresenter(children: [])
        presenter.view = view
        presenter.wireframe = wireframe

        let applicationConfig = MockApplicationConfigProtocol()
        let notificationRegistration = MockNotificationsRegistrationProtocol()

        let settings = InMemorySettingsManager()

        let eventCenter = MockEventCenterProtocol()
        let applicationHandler = ApplicationHandler()

        let walletContext = WalletContextMock()

        let dataStreamService = MockDataStreamServiceProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        stub(dataStreamService) { stub in
            when(stub).setup().thenDoNothing()
            when(stub).throttle().thenDoNothing()
        }

        let interactor = MainTabBarInteractor(eventCenter: eventCenter,
                                              settings: settings,
                                              applicationConfig: applicationConfig,
                                              applicationHandler: applicationHandler,
                                              notificationRegistrator: notificationRegistration,
                                              invitationLinkService: InvitationLinkService(settings: settings),
                                              walletContext: walletContext,
                                              userServices: [dataStreamService])

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

        let finishExpectation = XCTestExpectation()

        walletContext.closurePrepareAccountUpdateCommand = {
            finishExpectation.fulfill()

            return WalletCommandMock()
        }

        // when
        presenter.setup()

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: self)

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)
    }
 */
}
