/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol PinSetupViewProtocol: ControllerBackedProtocol {
    func didRequestBiometryUsage(
        biometryType: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)

    func didChangeAccessoryState(enabled: Bool)

    func didReceiveWrongPincode()
    
    func updatePinCodeSymbolsCount(with count: Int)
    func showUpdatePinRequestView()

    func blockUserInputUntil(date: Date)
    func showLastChanceAlert()
}

protocol PinSetupPresenterProtocol: UpdateRequestPinViewDelegate {
    func start()
    func cancel()
    func activateBiometricAuth()
    func submit(pin: String)
    var isChangeMode: Bool { get }
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

protocol PinUpdatable: AnyObject {
    func showUpdatePinView(from view: UIViewController, with completion:  @escaping () -> Void)
}

protocol PinSetupWireframeProtocol: AlertPresentable, ErrorPresentable, PinUpdatable {
    func dismiss(from view: PinSetupViewProtocol?)
    func showMain(from view: PinSetupViewProtocol?)
    func showSignup(from view: PinSetupViewProtocol?)
    func showPinUpdatedNotify(
        from view: PinSetupViewProtocol?,
        completionBlock: @escaping () -> Void)
}

protocol PinViewFactoryProtocol: class {
    static func createPinEditView() -> PinSetupViewProtocol?
    static func createPinSetupView() -> PinSetupViewProtocol?
    static func createPinUpdateView(completion: @escaping () -> Void) -> PinSetupViewProtocol?
    static func createSecuredPinView() -> PinSetupViewProtocol?
    static func createScreenAuthorizationView(with wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool)
        -> PinSetupViewProtocol?
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
