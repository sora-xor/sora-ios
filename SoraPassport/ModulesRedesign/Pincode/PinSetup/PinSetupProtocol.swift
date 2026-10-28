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
