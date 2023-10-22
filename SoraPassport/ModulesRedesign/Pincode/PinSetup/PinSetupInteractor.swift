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
import LocalAuthentication
import SoraKeystore

class PinSetupInteractor {
    public enum PinSetupState {
        case waitingPincode
        case waitingBiometrics
        case submitingPincode
        case submitedPincode
    }

    weak var presenter: PinSetupInteractorOutputProtocol?

    private(set) var config: ApplicationConfigProtocol
    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol

    init(secretManager: SecretStoreManagerProtocol,
         settingsManager: SettingsManagerProtocol,
         biometryAuth: BiometryAuthProtocol,
         config: ApplicationConfigProtocol
    ) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.config = config
    }

    private(set) var pincode: String?
    private(set) var state: PinSetupState = .waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                presenter?.didChangeState(from: oldValue)
            }
        }
    }

    private func processResponseForBiometrics(result: Bool) {
        guard state == .waitingBiometrics else { return }

        settingsManager.biometryEnabled = result

        state = .submitingPincode

        submitPincode()
    }

    private func submitPincode() {
        guard state == .submitingPincode, let currentPincode = pincode else { return }

        secretManager.saveSecret(currentPincode,
                                 for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main) { _ -> Void in
                                    self.completeSetup()
        }
    }

    private func completeSetup() {
        state = .submitedPincode
        pincode = nil
        self.presenter?.didSavePin()
    }
}

extension PinSetupInteractor: PinSetupInteractorInputProtocol {
    func process(pin: String) {
        guard state == .waitingPincode else { return }

        self.pincode = pin

        let authType = biometryAuth.availableBiometryType
        if authType != .none {
            state = .waitingBiometrics

            presenter?.didStartWaitingBiometryDecision(type: authType) { [weak self] (result: Bool) -> Void in

                self?.processResponseForBiometrics(result: result)
            }

        } else {
            state = .submitingPincode
            submitPincode()
        }
    }

    func change(pin: String) {
        guard state == .waitingPincode else { return }

        self.pincode = pin

        state = .submitingPincode

        submitPincode()
    }
}
