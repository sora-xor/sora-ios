/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

class NotificationsInteractor: NotificationsInteractorInputProtocol {
    private(set) var presenter: NotificationsInteractorOutputProtocol

    private(set) var config: ApplicationConfigProtocol
    private(set) var notificationUnitService: NotificationUnitServiceProtocol
    private(set) var notificationsRegistrator: NotificationsRegistrationProtocol
    private(set) var notificationsLocalScheduler: NotificationsLocalSchedulerProtocol
    private(set) var eventCenter: EventCenterProtocol

    private var tokenExchangeOperation: Operation?
    private var registrationOperation: Operation?
    private var permissionOperation: Operation?

    init(presenter: NotificationsInteractorOutputProtocol,
         eventCenter: EventCenterProtocol,
         config: ApplicationConfigProtocol,
         notificationUnitService: NotificationUnitServiceProtocol,
         notificationsRegistrator: NotificationsRegistrationProtocol,
         notificationsLocalScheduler: NotificationsLocalSchedulerProtocol) {

        self.presenter = presenter
        self.config = config
        self.notificationUnitService = notificationUnitService
        self.notificationsRegistrator = notificationsRegistrator
        self.notificationsLocalScheduler = notificationsLocalScheduler
        self.eventCenter = eventCenter
    }

    private func sendPushNotitificationInfoOrRegister(with token: String) {
        if tokenExchangeOperation != nil {
            return
        }

        let tokenInfo = TokenExchangeInfo(newToken: token)

        tokenExchangeOperation = try? notificationUnitService
            .exchangeTokens(with: tokenInfo,
                            runCompletionIn: .main) { [weak self] (optionalResult) in
                                self?.tokenExchangeOperation = nil

                                if let result = optionalResult {
                                    self?.processTokenExchange(result: result, for: token)
                                }
        }
    }

    private func processTokenExchange(result: OperationResult<Bool>, for token: String) {
        switch result {
        case .success:
            sendEnabledPermissions()
        case .error(let error):
            guard let tokenExchangeError = error as? NotificationTokenExchangeDataError else {
                presenter.didReceiveNotificationsSetup(error: error)
                return
            }

            if tokenExchangeError == .userNotFound {
                register(with: token)
            } else if tokenExchangeError == .tokenAlreadyExists {
                sendEnabledPermissions()
            } else {
                presenter.didReceiveNotificationsSetup(error: error)
            }
        }
    }

    private func sendEnabledPermissions() {
        if permissionOperation != nil {
            return
        }

        permissionOperation = try? notificationUnitService
            .enablePermission(for: [config.projectDecentralizedId],
                              runCompletionIn: .main) { [weak self] (operationResult) in
                                self?.permissionOperation = nil

                                if let result = operationResult {
                                    self?.processPermissions(result: result)
                                }
        }
    }

    private func processPermissions(result: OperationResult<Bool>) {
        switch result {
        case .success:
            presenter.didCompleteNotificationsSetup()
        case .error(let error):
            presenter.didReceiveNotificationsSetup(error: error)
        }
    }

    private func register(with token: String) {
        if registrationOperation != nil {
            return
        }

        let notificationInfo = NotificationUserInfo(tokens: [token],
                                                    allowedDecentralizedIds: [config.projectDecentralizedId])

        registrationOperation = try? notificationUnitService
            .registerUser(with: notificationInfo,
                          runCompletionIn: .main) { [weak self] (optionalResult) in
                            self?.registrationOperation = nil

                            if let result = optionalResult {
                                self?.processRegistration(result: result)
                            }
        }
    }

    private func processRegistration(result: OperationResult<Bool>) {
        switch result {
        case .success:
            presenter.didCompleteNotificationsSetup()
        case .error(let error):
            presenter.didReceiveNotificationsSetup(error: error)
        }
    }
}

extension NotificationsInteractor: NotificationsServiceOutputProtocol {
    func didReceive(remoteToken: String) {
        sendPushNotitificationInfoOrRegister(with: remoteToken)
    }

    func didReceive(_ notification: SoraNotificationProtocol) -> Bool {
        eventCenter.notify(with: PushNotificationEvent(notification: notification))
        return presenter.didReceive(notification)
    }
}
