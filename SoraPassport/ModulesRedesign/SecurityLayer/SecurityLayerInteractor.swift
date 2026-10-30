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
import UIKit
import SoraKeystore
import SoraFoundation

final class SecurityLayerInteractor {
    /// A PIN state the Keychain cannot answer for is `unavailable`, never
    /// "no PIN required".
    private enum AuthorizationRequirement {
        case required
        case notRequired
        case unavailable
    }

    var presenter: SecurityLayerInteractorOutputProtocol!
    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol

    private(set) var applicationHandler: ApplicationHandlerProtocol

    /// `uptime()` when the app last resigned active. Cleared only by a
    /// definitive decision, so a Keychain error cannot consume the check.
    private var backgroundEnterUptime: TimeInterval?
    /// A return found the Keychain locked (protected data not available yet).
    /// Protected data becoming available decides again before the app leaves.
    private var isDecisionDeferred = false
    /// From didBecomeActive until the next willResignActive.
    private var isActive = false
    private var protectedDataObserver: NSObjectProtocol?

    let pincodeDelay: TimeInterval
    private let uptime: () -> TimeInterval
    private let isProtectedDataAvailable: () -> Bool
    private let notificationCenter: NotificationCenter

    private var authorizationRequirement: AuthorizationRequirement {
        // While this install's PIN is not set yet (onboarding that started
        // from Welcome back), `pincode` is an earlier install's PIN: asking
        // for it on return from the background could stop a user who does
        // not remember it, with no way on.
        do {
            if let account = settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) {
                guard try !WalletOwnerPIN(keystore: keystore, settings: settings)
                    .requiresInitialSetup(accounts: [account]) else { return .notRequired }
            } else if WalletPendingPinSetup.isPending(settings) {
                // Only an onboarding presentation hint when no wallet row is selected.
                return .notRequired
            }
            let hasPincode = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
            return hasPincode ? .required : .notRequired
        } catch {
            return .unavailable
        }
    }

    init(applicationHandler: ApplicationHandlerProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         pincodeDelay: TimeInterval,
         uptime: @escaping () -> TimeInterval = SecurityLayerInteractor.continuousUptime,
         isProtectedDataAvailable: @escaping () -> Bool = { UIApplication.shared.isProtectedDataAvailable },
         notificationCenter: NotificationCenter = .default) {
        self.applicationHandler = applicationHandler
        self.settings = settings
        self.keystore = keystore
        self.pincodeDelay = pincodeDelay
        self.uptime = uptime
        self.isProtectedDataAvailable = isProtectedDataAvailable
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let protectedDataObserver {
            notificationCenter.removeObserver(protectedDataObserver)
        }
    }

    /// Seconds on a clock that never goes backwards and that setting the date
    /// does not move. Unlike `ProcessInfo.systemUptime`, it also counts the
    /// time the device sleeps: a phone locked for an hour was away an hour.
    static func continuousUptime() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
    }

    /// Before protected data is available the Keychain cannot answer yet: the
    /// check stays pending behind the privacy cover. After that, a PIN state
    /// that still cannot be read asks for the PIN, whose screen handles its
    /// own Keychain and recovery errors, so an error never locks the user out.
    private func checkAuthorizationRequirement(uncover: Bool) {
        var requirement = AuthorizationRequirement.notRequired
        if let backgroundEnterUptime {
            let elapsed = uptime() - backgroundEnterUptime
            // A reading before the start (a reset clock) counts as the delay reached.
            if !(elapsed >= 0 && elapsed < pincodeDelay) {
                requirement = authorizationRequirement
            }
        }

        if requirement == .unavailable {
            guard isProtectedDataAvailable() else {
                isDecisionDeferred = true
                return
            }
            requirement = .required
        }

        isDecisionDeferred = false
        backgroundEnterUptime = nil

        if uncover {
            presenter.didDecideUnsecurePresentation()
        }

        if requirement == .required {
            presenter.didDecideRequestAuthorization()
        }
    }
}

extension SecurityLayerInteractor: SecurityLayerInteractorInputProtocol {
    func setup() {
        applicationHandler.delegate = self

        guard protectedDataObserver == nil else { return }
        // Keychain items cannot be read before protected data is available.
        protectedDataObserver = notificationCenter.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isDecisionDeferred else { return }
            self.checkAuthorizationRequirement(uncover: self.isActive)
        }
    }
}

extension SecurityLayerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification: Notification) {
        checkAuthorizationRequirement(uncover: false)
    }

    func didReceiveDidBecomeActive(notification: Notification) {
        isActive = true
        checkAuthorizationRequirement(uncover: true)
    }

    func didReceiveWillResignActive(notification: Notification) {
        isActive = false
        isDecisionDeferred = false
        presenter.didDecideSecurePresentation()

        // An absence still waiting for the Keychain keeps its start.
        if backgroundEnterUptime == nil {
            backgroundEnterUptime = uptime()
        }
    }
}
