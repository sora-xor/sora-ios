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
import SoraUIKit

enum InputMode {
    case verify
    case create
    case confirm
    
    var title: String {
        switch self {
        case .confirm: return R.string.localizable.pincodeConfirmYourPinCode(preferredLanguages: .currentLocale).capitalized
        case .create: return R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized
        case .verify: return R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized
        }
    }
}

class InputPincodePresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var wireframe: PinSetupWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
    var isNeedUpdateTo6Symbols: Bool = false
    let formatter = DateComponentsFormatter()
    private var verificationPinLength: Int?
    private var isCheckingPin = false
    private var isLoadingPinLength = false
    private var isOwnerPinRequired = false
    
    public var mode: InputMode = .verify {
        didSet {
            view?.setupTitleLabel(text: mode == .verify ? verifyTitle : mode.title)
            view?.resetTitleColor()
        }
    }

    /// Says why Face ID or Touch ID did not start this time.
    private var verifyTitle: String {
        isOwnerPinRequired ? LocalAuthInteractor.ownerPinEntryTitle : InputMode.verify.title
    }
    
    var inputedPinCode: String = "" {
        didSet {
            view?.updateInputedCircles(with: inputedPinCode.count)
            view?.setupDeleteButton(isHidden: inputedPinCode.isEmpty)
        }
    }
    
    var savedPinCode: String = "" {
        didSet {
            let setup = R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized
            let confirm = R.string.localizable.pincodeConfirmYourPinCode(preferredLanguages: .currentLocale).capitalized
            view?.setupTitleLabel(text: savedPinCode.isEmpty ? setup : confirm)
            view?.resetTitleColor()
        }
    }

    func start() {
        requestPinLength()
        if let date = interactor.getInputBlockDate(), date.timeIntervalSinceNow > 0 {
            view?.blockUserInputUntil(date: date)
            return
        } else {
            mode = .verify
        }

        view?.didChangeAccessoryState(enabled: interactor.allowManualBiometryAuth)
        interactor.startAuth { [weak self] in
            self?.view?.askBiometryPermission()
        }
    }

    func cancel() {}

    func activateBiometricAuth() {
        interactor.startAuth { [weak self] in
            self?.view?.askBiometryPermission()
        }
    }

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
    
    func updatePinButtonTapped() {
        mode = .create
        inputedPinCode = ""
        isCheckingPin = false
        view?.updatePinCodeSymbolsCount(with: 6)
    }
    
    func deleteButtonTapped() {
        guard !inputedPinCode.isEmpty else { return }
        inputedPinCode = String(inputedPinCode.dropLast())
    }

    func padButtonTapped(with symbol: String) {
        if mode == .verify, verificationPinLength == nil {
            if !isLoadingPinLength { requestPinLength() }
            return
        }
        let requiredLength = mode == .verify ? verificationPinLength : 6
        guard let requiredLength, !isCheckingPin, inputedPinCode.count < requiredLength,
              symbol.count == 1, symbol.allSatisfy({ $0.isNumber }) else { return }

        inputedPinCode += symbol
        view?.setupDeleteButton(isHidden: inputedPinCode.isEmpty)
        
        if inputedPinCode.count == requiredLength, mode == .verify {
            isCheckingPin = true
            interactor.process(pin: inputedPinCode)
            return
        }
        
        if !savedPinCode.isEmpty, savedPinCode == inputedPinCode {
            interactor.updatePin(pin: savedPinCode) {
                self.wireframe.showMain(from: self.view)
            }
            return
        }
        
        if !savedPinCode.isEmpty, savedPinCode != inputedPinCode, inputedPinCode.count == 6 {
            view?.animateWrongInputError() { [weak self] _ in
                self?.savedPinCode = ""
                self?.inputedPinCode = ""
                self?.mode = .create
            }
            return
        }
        
        if inputedPinCode.count == 6 {
            savedPinCode = inputedPinCode
            inputedPinCode = ""
            return
        }
    }
    private func requestPinLength() {
        isLoadingPinLength = true
        view?.setupTitleLabel(text: "Checking PIN availability…")
        interactor.getPinCodeCount()
    }

}

extension InputPincodePresenter: LocalAuthInteractorOutputProtocol {

    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.animateWrongInputError() { [weak self] _ in
                self?.inputedPinCode = ""
                self?.isCheckingPin = false
                self?.mode = .verify
            }
        }
    }

    func blockUserInputUntil(date: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.blockUserInputUntil(date: date)
        }
    }

    func reachedLastChancePinInput() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.showLastChanceAlert()
        }
    }

    func didChangeState(from state: LocalAuthInteractor.LocalAuthState) {}
    
    func didCompleteAuth() {
        DispatchQueue.main.async {
            guard self.isNeedUpdateTo6Symbols else {
                self.wireframe.showMain(from: self.view)
                return
            }

            self.mode = .create
            self.view?.showUpdatePinRequestView()
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showSignup(from: self?.view)
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
        isNeedUpdateTo6Symbols = count == 4
        view?.updatePinCodeSymbolsCount(with: count)
    }

    func didRequireOwnerPinEntry() {
        isOwnerPinRequired = true
        view?.didChangeAccessoryState(enabled: false)
        guard mode == .verify, verificationPinLength != nil, !isCheckingPin else { return }
        view?.setupTitleLabel(text: verifyTitle)
    }
}
