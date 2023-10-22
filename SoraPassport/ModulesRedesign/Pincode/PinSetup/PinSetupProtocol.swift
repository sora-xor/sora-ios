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

import UIKit
import SoraUIKit

protocol PinSetupViewProtocol: ControllerBackedProtocol, ApplicationSettingsPresentable {
    func didRequestBiometryUsage(
        biometryType: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)

    func didChangeAccessoryState(enabled: Bool)

    func didReceiveWrongPincode()
    
    func updatePinCodeSymbolsCount(with count: Int)
    func showUpdatePinRequestView()

    func blockUserInputUntil(date: Date)
    func showLastChanceAlert()
    
    func updateInputedCircles(with count: Int)
    func setupDeleteButton(isHidden: Bool)
    func setupTitleLabel(text: String)
    func resetTitleColor()
    func animateWrongInputError(with completion: @escaping (Bool) -> Void)
    func askBiometryPermission()
}

protocol PinSetupPresenterProtocol {
    func start()
    func cancel()
    func activateBiometricAuth()
    func submit(pin: String)
    var isChangeMode: Bool { get }
    func deleteButtonTapped()
    func padButtonTapped(with symbol: String)
    func updatePinButtonTapped()
}

extension PinSetupPresenterProtocol {
    var isChangeMode: Bool {
        return false
    }
}

protocol PinSetupInteractorInputProtocol: AnyObject {
    func process(pin: String)
    func change(pin: String)
}

extension PinSetupInteractorInputProtocol {
    func change(pin: String) {
        process(pin: pin)
    }
}

protocol PinSetupInteractorOutputProtocol: AnyObject {
    func didSavePin()
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)
    func didChangeState(from: PinSetupInteractor.PinSetupState)
    func didReceiveConfigError(_ error: Swift.Error)
}

extension PinSetupInteractorOutputProtocol {
    func didReceiveConfigError(_ error: Swift.Error) { }
}

protocol PinSetupWireframeProtocol: AlertPresentable, ErrorPresentable {
    func dismiss(from view: PinSetupViewProtocol?)
    func showMain(from view: PinSetupViewProtocol?)
    func showSignup(from view: PinSetupViewProtocol?)
    func showPinUpdatedNotify(
        from view: PinSetupViewProtocol?,
        completionBlock: @escaping () -> Void)
}

enum PinAppearanceAnimationConstants {
    static let type = CATransitionType.moveIn
    static let subtype = CATransitionSubtype.fromTop
    static let timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
    static let duration = 0.3
    static let animationKey = "pin.transitionIn"
}

enum PinDismissAnimationConstants {
    static let type = CATransitionType.fade
    static let timingFunction = CAMediaTimingFunctionName.easeOut
    static let duration = 0.3
    static let animationKey = "pin.transitionOut"
}
