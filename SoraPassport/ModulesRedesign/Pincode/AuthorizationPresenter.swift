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

final class AuthorizationPresenter {
    weak var view: PinSetupViewProtocol?
    var wireframe: ScreenAuthorizationWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
    private var verificationPinLength: Int?
    private var isCheckingPin = false
    private var isLoadingPinLength = false
    private var isOwnerPinRequired = false
    
    var inputedPinCode: String = "" {
        didSet {
            view?.setupTitleLabel(text: verifyTitle)
            view?.resetTitleColor()
            view?.updateInputedCircles(with: inputedPinCode.count)
            view?.setupDeleteButton(isHidden: inputedPinCode.isEmpty)
        }
    }

    /// Says why Face ID or Touch ID did not start this time.
    private var verifyTitle: String {
        isOwnerPinRequired ? LocalAuthInteractor.ownerPinEntryTitle
            : R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized
    }
    private func requestPinLength() {
        isLoadingPinLength = true
        view?.setupTitleLabel(text: "Checking PIN availability…")
        interactor.getPinCodeCount()
    }

}

extension AuthorizationPresenter: PinSetupPresenterProtocol {
    func start() {
        requestPinLength()

        if let date = interactor.getInputBlockDate(), date.timeIntervalSinceNow > 0 {
            view?.blockUserInputUntil(date: date)
            return
        }

        view?.didChangeAccessoryState(enabled: interactor.allowManualBiometryAuth)
        interactor.startAuth { [weak self] in
            self?.view?.askBiometryPermission()
        }
    }

    func cancel() {
        wireframe.showAuthorizationCompletion(with: false)
    }

    func activateBiometricAuth() {
        interactor.startAuth { [weak self] in
            self?.view?.askBiometryPermission()
        }
    }

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
    
    func deleteButtonTapped() {
        guard !inputedPinCode.isEmpty else { return }
        inputedPinCode = String(inputedPinCode.dropLast())
    }

    func padButtonTapped(with symbol: String) {
        guard verificationPinLength != nil else {
            if !isLoadingPinLength { requestPinLength() }
            return
        }
        guard let requiredLength = verificationPinLength, !isCheckingPin,
              inputedPinCode.count < requiredLength,
              symbol.count == 1, symbol.allSatisfy({ $0.isNumber }) else { return }

        inputedPinCode += symbol
        view?.setupDeleteButton(isHidden: inputedPinCode.isEmpty)
        
        if inputedPinCode.count == requiredLength {
            isCheckingPin = true
            interactor.process(pin: inputedPinCode)
        }
    }
    func updatePinButtonTapped() {}
}

extension AuthorizationPresenter: LocalAuthInteractorOutputProtocol {
    func reachedLastChancePinInput() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.showLastChanceAlert()
        }
    }
    func blockUserInputUntil(date: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.blockUserInputUntil(date: date)
        }
    }

    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.animateWrongInputError() { [weak self] _ in
                self?.inputedPinCode = ""
                self?.isCheckingPin = false
            }
        }
    }

    func setupPinCodeSymbols(with count: Int) {
        isLoadingPinLength = false
        guard count == 4 || count == 6 else {
            verificationPinLength = nil
            view?.setupTitleLabel(text: "PIN unavailable. Unlock your iPhone, then tap a number to retry.")
            return
        }
        view?.setupTitleLabel(text: verifyTitle)
        verificationPinLength = count
        view?.updatePinCodeSymbolsCount(with: count)
    }

    func didRequireOwnerPinEntry() {
        isOwnerPinRequired = true
        view?.didChangeAccessoryState(enabled: false)
        guard verificationPinLength != nil, !isCheckingPin else { return }
        view?.setupTitleLabel(text: verifyTitle)
    }

    func didChangeState(from state: LocalAuthInteractor.LocalAuthState) {}

    func didCompleteAuth() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showAuthorizationCompletion(with: true)
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showAuthorizationCompletion(with: false)
        }
    }
}
