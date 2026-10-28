// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SoraKeystore
import SoraFoundation

final class SecurityLayerInteractor {
    var presenter: SecurityLayerInteractorOutputProtocol!
    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol

    private(set) var applicationHandler: ApplicationHandlerProtocol

    private var backgroundEnterDate: Date?

    let pincodeDelay: TimeInterval
    private let currentDate: () -> Date

    private var canEnterPincode: Bool {
        // While this install's PIN is not set yet (onboarding that started
        // from Welcome back), `pincode` is an earlier install's PIN: asking
        // for it on return from the background could stop a user who does
        // not remember it, with no way on.
        do {
            if let account = settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) {
                guard try !WalletOwnerPIN(keystore: keystore, settings: settings)
                    .requiresInitialSetup(accounts: [account]) else { return false }
            } else if WalletPendingPinSetup.isPending(settings) {
                // Only an onboarding presentation hint when no wallet row is selected.
                return false
            }
            let hasPincode = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
            return hasPincode
        } catch {
            return false
        }
    }

    init(applicationHandler: ApplicationHandlerProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         pincodeDelay: TimeInterval,
         currentDate: @escaping () -> Date = Date.init) {
        self.applicationHandler = applicationHandler
        self.settings = settings
        self.keystore = keystore
        self.pincodeDelay = pincodeDelay
        self.currentDate = currentDate
    }

    private func checkAuthorizationRequirement() {
        guard let backgroundEnterDate = backgroundEnterDate else {
            return
        }

        self.backgroundEnterDate = nil

        if canEnterPincode {
            let pincodeDelayReached = currentDate().timeIntervalSince(backgroundEnterDate) >= pincodeDelay

            if pincodeDelayReached {
                presenter.didDecideRequestAuthorization()
            }
        }
    }
}

extension SecurityLayerInteractor: SecurityLayerInteractorInputProtocol {
    func setup() {
        applicationHandler.delegate = self
    }
}

extension SecurityLayerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification: Notification) {
        checkAuthorizationRequirement()
    }

    func didReceiveDidBecomeActive(notification: Notification) {
        presenter.didDecideUnsecurePresentation()
        checkAuthorizationRequirement()
    }

    func didReceiveWillResignActive(notification: Notification) {
        presenter.didDecideSecurePresentation()

        backgroundEnterDate = currentDate()
    }
}
