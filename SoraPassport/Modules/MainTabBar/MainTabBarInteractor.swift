/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import CommonWallet
import SoraFoundation

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let applicationConfig: ApplicationConfigProtocol
    let notificationRegistrator: NotificationsRegistrationProtocol
    let settings: SettingsManagerProtocol
    let invitationLinkService: InvitationLinkServiceProtocol
    let walletContext: CommonWalletContextProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let userServices: [UserApplicationServiceProtocol]

    var logger: LoggerProtocol?

    deinit {
        userServices.forEach { $0.throttle() }
    }

    init(eventCenter: EventCenterProtocol,
         settings: SettingsManagerProtocol,
         applicationConfig: ApplicationConfigProtocol,
         applicationHandler: ApplicationHandlerProtocol,
         notificationRegistrator: NotificationsRegistrationProtocol,
         invitationLinkService: InvitationLinkServiceProtocol,
         walletContext: CommonWalletContextProtocol,
         userServices: [UserApplicationServiceProtocol]) {

        self.eventCenter = eventCenter
        self.settings = settings
        self.applicationConfig = applicationConfig
        self.notificationRegistrator = notificationRegistrator
        self.invitationLinkService = invitationLinkService
        self.walletContext = walletContext
        self.applicationHandler = applicationHandler
        self.userServices = userServices

        setup()
    }

    private func setup() {
        eventCenter.add(observer: self)
        applicationHandler.delegate = self

        userServices.forEach { $0.setup() }
    }

    private func updateWalletAccount() {
        do {
            try walletContext.prepareAccountUpdateCommand().execute()
        } catch {
            logger?.error("Can't update wallet account due to error \(error)")
        }
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {

    func configureNotifications() {
        let options = NotificationsOptions(rawValue: applicationConfig.notificationOptions)
        notificationRegistrator.registerNotifications(options: options)
        notificationRegistrator.registerForRemoteNotifications()
    }

    func configureDeepLink() {
        invitationLinkService.add(observer: self)
    }

    func searchPendingDeepLink() {
        if let link = invitationLinkService.link {
            presenter?.didReceive(deepLink: link)
        }
    }

    func resolvePendingDeepLink() {
        invitationLinkService.clear()
    }
}

extension MainTabBarInteractor: InvitationLinkObserver {
    func didUpdateInvitationLink(from oldLink: InvitationDeepLink?) {
        if let link = invitationLinkService.link {
            presenter?.didReceive(deepLink: link)
        }
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processPushNotification(event: PushNotificationEvent) {
        updateWalletAccount()
    }

    func processWalletUpdate(event: WalletUpdateEvent) {
        updateWalletAccount()
    }
}

extension MainTabBarInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification: Notification) {
        updateWalletAccount()
    }
}
