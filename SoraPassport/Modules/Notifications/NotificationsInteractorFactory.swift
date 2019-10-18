/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraCrypto
import SoraKeystore

class NotificationsInteractorFactory: NotificationsInteractorFactoryProtocol {
    typealias InteractorType = NotificationsInteractor
    func createNotificationsInteractor() -> InteractorType {
        let presenter = NotificationsPresenter()
        presenter.wireframe = NotificationsWireframe()
        presenter.logger = Logger.shared

        let requestSigner = createRequestSigner()
        let notificationService = NotificationUnitService(unit: ApplicationConfig.shared.defaultNotificationUnit,
                                                          requestSigner: requestSigner)

        let interactor = NotificationsInteractor(presenter: presenter,
                                                 eventCenter: EventCenter.shared,
                                                 config: ApplicationConfig.shared,
                                                 notificationUnitService: notificationService,
                                                 notificationsRegistrator: NotificationsRegistration(),
                                                 notificationsLocalScheduler: NotificationsLocalScheduler())

        return interactor
    }

    private func createRequestSigner() -> DARequestSigner {
        var requestSigner = DARequestSigner()

        if let decentralizedId = SettingsManager.shared.decentralizedId {
            requestSigner = requestSigner.with(decentralizedId: decentralizedId)
        } else {
            Logger.shared.error("Missing decetranlized id during request signer creation")
        }

        if let publicKeyId = SettingsManager.shared.publicKeyId {
            requestSigner = requestSigner.with(publicKeyId: publicKeyId)
        } else {
            Logger.shared.error("Missing public key id during request signer creation")
        }

        let rawSigner = IRSigningDecorator(keystore: Keychain(),
                                           identifier: KeystoreKey.privateKey.rawValue)
        rawSigner.logger = Logger.shared

        return requestSigner.with(rawSigner: rawSigner)
    }
}
