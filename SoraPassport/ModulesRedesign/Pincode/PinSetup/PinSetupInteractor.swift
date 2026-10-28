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
