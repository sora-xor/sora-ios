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
import SoraFoundation
import SoraUIKit

class SetupPincodePresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var interactor: PinSetupInteractorInputProtocol!
    var wireframe: PinSetupWireframeProtocol!
    var isUpdateTo6Symbols: Bool = false
    var isNeedChangePinCode: Bool = false
    var completion: (() -> Void)?
    
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
        view?.setupTitleLabel(text: R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized)
        view?.didChangeAccessoryState(enabled: false)
        view?.updatePinCodeSymbolsCount(with: 6)
    }

    func activateBiometricAuth() {}

    func cancel() {}

    func submit(pin: String) {
        if isNeedChangePinCode {
            interactor.change(pin: pin)
            return
        }
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
        
        if !savedPinCode.isEmpty, savedPinCode == inputedPinCode {
            if isNeedChangePinCode {
                interactor.change(pin: savedPinCode)
                return
            }
            interactor.process(pin: savedPinCode)
            return
        }
        
        if !savedPinCode.isEmpty, savedPinCode != inputedPinCode, inputedPinCode.count == 6 {
            view?.animateWrongInputError() { [weak self] _ in
                self?.savedPinCode = ""
                self?.inputedPinCode = ""
            }
            return
        }
        
        if inputedPinCode.count == 6 {
            savedPinCode = inputedPinCode
            inputedPinCode = ""
            return
        }
    }
}

extension SetupPincodePresenter: PinSetupInteractorOutputProtocol {
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void) {

        DispatchQueue.main.async { [weak self] in
            self?.view?.didRequestBiometryUsage(biometryType: type, completionBlock: completionBlock)
        }
    }

    func didSavePin() {
        DispatchQueue.main.async {
            guard self.isUpdateTo6Symbols else {
                if self.isNeedChangePinCode {
                    self.wireframe.dismiss(from: self.view)
                } else {
                    self.wireframe.showMain(from: self.view)
                }
                return
            }

            self.completion?()
        }
    }

    func didReceiveConfigError(_ error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = self.wireframe.present(error: error, from: nil, locale: LocalizationManager.shared.selectedLocale)
        }

    }

    func didChangeState(from: PinSetupInteractor.PinSetupState) {}
    func updatePinButtonTapped() {}
}
