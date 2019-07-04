/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto
import SoraCrypto
import RobinHood

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol
    var securityLayerService: SecurityLayerInteractorInputProtocol

    init(settings: SettingsManagerProtocol, keystore: KeystoreProtocol,
         securityLayerService: SecurityLayerInteractorInputProtocol) {
        self.settings = settings
        self.keystore = keystore
        self.securityLayerService = securityLayerService
    }

    private func configureSecurityService() {
        securityLayerService.setup()
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        if settings.decentralizedId == nil || settings.hasVerificationState {
            presenter?.didDecideOnboarding()
            return
        }

        do {
            let pincodeExists = try keystore.checkKey(for: KeystoreKey.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecideAuthVerification()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }

    func setup() {
        configureSecurityService()
    }
}
