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

enum FailureAuthCount: Int {
    case zero = 0
    case first
    case second
    case third
    case fourth
    case fifth
    case sixth
    case seventh
    case eighth
    case ninth
    case unknown

    init(value: Int) {
        if let count = FailureAuthCount(rawValue: value) {
            self = count
        } else {
            self = .unknown
        }
    }

    var cooldownMinutes: Int {
        switch self {
        case .third: return 1
        case .fourth: return 5
        case .fifth: return 15
        case .sixth, .seventh, .eighth, .ninth, .unknown: return 30
        case .zero, .first, .second: return 0
        }
    }

    var isLastTry: Bool {
        return self == .second
    }

    var isBlockedTry: Bool {
        return self.rawValue >= FailureAuthCount.third.rawValue
    }
}

class LocalAuthInteractor {

    enum LocalAuthState {
        case waitingPincode
        case checkingPincode
        case checkingBiometry
        case completed
        case unexpectedFail
    }

    weak var presenter: LocalAuthInteractorOutputProtocol?
    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol
    private(set) var locale: Locale
    private var failCounter: Int = 0 {
        didSet {
            settingsManager.failInputPinCount = failCounter

            let failCount = FailureAuthCount(rawValue: failCounter) ?? .unknown

            guard !failCount.isLastTry else {
                presenter?.reachedLastChancePinInput()
                return
            }

            guard failCount.isBlockedTry else {
                return
            }
            
            let blockTimeInterval = TimeInterval(60 * failCount.cooldownMinutes)
            let date = Date().addingTimeInterval(blockTimeInterval)
            
            settingsManager.inputBlockTimeInterval = Int(date.timeIntervalSince1970)
            presenter?.blockUserInputUntil(date: date)
        }
    }

    init(secretManager: SecretStoreManagerProtocol,
         settingsManager: SettingsManagerProtocol,
         biometryAuth: BiometryAuthProtocol,
         locale: Locale) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.locale = locale
        self.failCounter = settingsManager.failInputPinCount ?? 0
    }

    private(set) var state = LocalAuthState.waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                presenter?.didChangeState(from: oldValue)
            }
        }
    }

    private(set) var pincode: String?

    private func performBiometryAuth(completion: (() -> Void)?) {
        guard state == .checkingBiometry else { return }

        let biometryUsageOptional = settingsManager.biometryEnabled

        guard let biometryUsage = biometryUsageOptional, biometryUsage else {
            state = .waitingPincode
            return
        }

        guard biometryAuth.availableBiometryType != .none else {
            state = .waitingPincode
            completion?()
            return
        }

        biometryAuth.authenticate(
            localizedReason: R.string.localizable.askBiometryReason(preferredLanguages: locale.rLanguages),
            completionQueue: DispatchQueue.main) { [weak self] (result: Bool) -> Void in

            self?.processBiometryAuth(result: result)
        }
    }

    private func processBiometryAuth(result: Bool) {
        guard state == .checkingBiometry else {
            return
        }

        if result {
           state = .completed
            presenter?.didCompleteAuth()
            failCounter = 0
            return
        }

        state = .waitingPincode
    }

    private func processStored(pin: String?) {
        guard state == .checkingPincode else {
            return
        }

        if pincode == pin {
            state = .completed
            pincode = nil
            presenter?.didCompleteAuth()
            failCounter = 0
        } else {
            state = .waitingPincode
            pincode = nil
            presenter?.didEnterWrongPincode()
            failCounter += 1
        }
    }
}

extension LocalAuthInteractor: LocalAuthInteractorInputProtocol {
    func getInputBlockDate() -> Date? {
        guard let timeInterval = settingsManager.inputBlockTimeInterval else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timeInterval))
    }

    var allowManualBiometryAuth: Bool {
        return settingsManager.biometryEnabled == true
    }
    
    func getPinCodeCount() {
        secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main
        ) { [weak self] (secret: SecretDataRepresentable?) -> Void in
            self?.presenter?.setupPinCodeSymbols(with: secret?.toUTF8String()?.count ?? 6) 
        }
    }

    func startAuth(completion: (() -> Void)?) {
        guard state == .waitingPincode else { return }

        state = .checkingBiometry
        performBiometryAuth(completion: completion)
    }

    func process(pin: String) {
        guard state == .waitingPincode || state == .checkingBiometry else { return }

        self.pincode = pin

        state = .checkingPincode

        secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main
        ) { [weak self] (secret: SecretDataRepresentable?) -> Void in
            self?.processStored(pin: secret?.toUTF8String())
        }
    }
    
    func updatePin(pin: String, completion: (() -> Void)?) {
        self.pincode = pin
        
        guard let currentPincode = pincode else { return }
        
        secretManager.saveSecret(currentPincode,
                                 for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main) { _ -> Void in
            completion?()
        }
    }
}
