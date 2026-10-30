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
    private let ownerPIN: WalletOwnerPIN
    private let accounts: () throws -> [AccountItem]
    private var authorization: WalletOwnerPIN.Authorization?
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
         locale: Locale,
         ownerPINKeystore: KeystoreProtocol = Keychain(),
         recoveryGate: WalletRecoveryCapabilityGate = .shared,
         accounts: @escaping () throws -> [AccountItem] = { try WalletAccountAddresses.accounts() }) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.locale = locale
        self.ownerPIN = WalletOwnerPIN(keystore: ownerPINKeystore, settings: settingsManager, recoveryGate: recoveryGate)
        self.accounts = accounts
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

    /// Welcome back restores a wallet with its PIN only through its owner
    /// binding. A read error asks for the PIN too; it never skips it.
    private func needsOwnerPinBinding() -> Bool {
        (try? ownerPIN.hasBindings(accounts: accounts())) != true
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

    private func processAuthorization(_ result: Result<WalletOwnerPIN.Authorization, Error>) {
        guard state == .checkingPincode else { return }
        pincode = nil
        switch result {
        case let .success(authorization):
            self.authorization = authorization
            state = .completed
            failCounter = 0
            presenter?.didCompleteAuth()
        case let .failure(error):
            state = .waitingPincode
            if case let .locked(until)? = error as? WalletRetainedPinGate.Failure {
                presenter?.blockUserInputUntil(date: until)
            } else if error is WalletRetainedPinGate.Failure || error as? WalletOwnerPIN.Failure == .authenticationRequired {
                presenter?.didEnterWrongPincode()
                failCounter += 1
            } else {
                presenter?.didUnexpectedFail()
            }
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
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.ownerPIN.prepareAuthentication(currentAccounts: self.accounts)
                self.secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                    completionQueue: DispatchQueue.main) { [weak self] secret in
                    self?.presenter?.setupPinCodeSymbols(with: secret?.toUTF8String()?.count ?? 0)
                }
            } catch {
                DispatchQueue.main.async { self.presenter?.didUnexpectedFail() }
            }
        }
    }

    func startAuth(completion: (() -> Void)?) {
        guard state == .waitingPincode else { return }
        state = .checkingBiometry
        let biometryEnabled = settingsManager.biometryEnabled == true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.ownerPIN.prepareAuthentication(currentAccounts: self.accounts)
                let needsOwnerPin = biometryEnabled && self.needsOwnerPinBinding()
                self.secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                    completionQueue: DispatchQueue.main) { [weak self] secret in
                    guard let self, self.state == .checkingBiometry else { return }
                    // Upgrading a four-digit PIN requires its actual entry.
                    guard secret?.toUTF8String()?.count == 6 else {
                        self.state = .waitingPincode
                        return
                    }
                    // Biometry would leave the wallet without an owner binding.
                    guard !needsOwnerPin else {
                        self.state = .waitingPincode
                        self.presenter?.didRequireOwnerPinEntry()
                        return
                    }
                    self.performBiometryAuth(completion: completion)
                }
            } catch {
                DispatchQueue.main.async { self.state = .unexpectedFail; self.presenter?.didUnexpectedFail() }
            }
        }
    }

    func process(pin: String) {
        guard state == .waitingPincode || state == .checkingBiometry else { return }
        state = .checkingPincode
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try self.ownerPIN.authenticateCurrent(pin, currentAccounts: { (try? self.accounts()) ?? [] })
            }
            DispatchQueue.main.async { self.processAuthorization(result) }
        }
    }

    func updatePin(pin: String, completion: (() -> Void)?) {
        guard let authorization else { presenter?.didUnexpectedFail(); return }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                let lease = WalletLifecycleCoordinator.shared.acquire()
                defer { lease.release() }
                try self.ownerPIN.rotate(to: pin, authorization: authorization, accounts: self.accounts())
            }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.authorization = nil
                    completion?()
                case .failure:
                    self.pincode = nil
                    self.state = .unexpectedFail
                    self.presenter?.didUnexpectedFail()
                }
            }
        }
    }
}
