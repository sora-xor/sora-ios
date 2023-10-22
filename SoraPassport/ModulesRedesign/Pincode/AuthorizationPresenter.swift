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

final class AuthorizationPresenter {
    weak var view: PinSetupViewProtocol?
    var wireframe: ScreenAuthorizationWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
    
    var inputedPinCode: String = "" {
        didSet {
            view?.setupTitleLabel(text: R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized)
            view?.resetTitleColor()
            view?.updateInputedCircles(with: inputedPinCode.count)
            view?.setupDeleteButton(isHidden: inputedPinCode.isEmpty)
        }
    }
}

extension AuthorizationPresenter: PinSetupPresenterProtocol {
    func start() {
        view?.updatePinCodeSymbolsCount(with: 6)

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
        guard inputedPinCode.count <= 6 else {
            return
        }

        inputedPinCode += symbol
        view?.setupDeleteButton(isHidden: inputedPinCode.isEmpty)
        
        if inputedPinCode.count == 6 {
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
            }
        }
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
