import UIKit
import SoraUIKit

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
    
    func updateInputedCircles(with count: Int)
    func setupDeleteButton(isHidden: Bool)
    func setupTitleLabel(text: String)
    func resetTitleColor()
    func animateWrongInputError(with completion: @escaping (Bool) -> Void)
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
