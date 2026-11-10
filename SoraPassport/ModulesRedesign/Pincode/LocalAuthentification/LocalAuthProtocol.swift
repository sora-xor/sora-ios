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

import UIKit

protocol LocalAuthInteractorInputProtocol: AnyObject {
    var allowManualBiometryAuth: Bool { get }

    func startAuth(completion: (() -> Void)?)
    func process(pin: String)
    func getPinCodeCount()
    func getInputBlockDate() -> Date?
    func updatePin(pin: String, completion: (() -> Void)?)
}

protocol LocalAuthInteractorOutputProtocol: AnyObject {
    func didEnterWrongPincode()
    func blockUserInputUntil(date: Date)
    func reachedLastChancePinInput()
    func didChangeState(from state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
    func setupPinCodeSymbols(with count: Int)
    /// Biometry did not start: a wallet still needs an owner binding, which
    /// the typed PIN creates.
    func didRequireOwnerPinEntry()
    /// The typed PIN was right, but the faces or fingers enrolled on this iPhone
    /// changed since the owner approved them. Nothing goes on until they answer:
    /// true keeps Face ID or Touch ID with the set enrolled now, false turns it off.
    func didRequireEnrollmentDecision(type: AvailableBiometryType, completion: @escaping (Bool) -> Void)
    /// A pending PIN check or enrollment choice was discarded on backgrounding.
    func didInvalidatePendingPin()
}

extension LocalAuthInteractorOutputProtocol {
    func setupPinCodeSymbols(with count: Int) {}
    func didRequireOwnerPinEntry() {}
    func didInvalidatePendingPin() {}
}

extension LocalAuthInteractor {
    /// The PIN screens' title after `didRequireOwnerPinEntry()`.
    static var ownerPinEntryTitle: String {
        WalletUX.text("Enter your PIN. SORA needs it once to protect the wallets on this iPhone.")
    }
}

extension PinSetupViewProtocol {
    /// The question behind `didRequireEnrollmentDecision`.
    @discardableResult
    func askToKeepChangedBiometry(type: AvailableBiometryType, completion: @escaping (Bool) -> Void) -> UIAlertController {
        let name = type == .faceId ? "Face ID" : "Touch ID"
        let alert = UIAlertController(
            title: WalletUX.format("%@ changed on this iPhone", name),
            message: WalletUX.format(
                "A face or fingerprint was added or removed on this iPhone since %@ last unlocked SORA. "
                    + "Anyone whose face or fingerprint is on this iPhone can unlock your wallet. "
                    + "If you didn't make this change, turn %@ off.",
                name, name
            ),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WalletUX.format("Keep %@", name), style: .default) { _ in completion(true) })
        alert.addAction(UIAlertAction(title: WalletUX.format("Turn %@ off", name), style: .destructive) { _ in completion(false) })
        controller.present(alert, animated: true)
        return alert
    }
}
