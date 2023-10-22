// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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

    private var canEnterPincode: Bool {
        do {
            let hasPincode = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
            return hasPincode
        } catch {
            return false
        }
    }

    init(applicationHandler: ApplicationHandlerProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         pincodeDelay: TimeInterval) {
        self.applicationHandler = applicationHandler
        self.settings = settings
        self.keystore = keystore
        self.pincodeDelay = pincodeDelay
    }

    private func checkAuthorizationRequirement() {
        guard let backgroundEnterDate = backgroundEnterDate else {
            return
        }

        self.backgroundEnterDate = nil

        if canEnterPincode {
            let pincodeDelayReached = Date().timeIntervalSince(backgroundEnterDate) >= pincodeDelay

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

        backgroundEnterDate = Date()
    }
}
