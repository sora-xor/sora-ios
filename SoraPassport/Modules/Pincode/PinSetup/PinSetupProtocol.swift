import UIKit

protocol PinSetupViewProtocol: ControllerBackedProtocol {
    func didRequestBiometryUsage(
        biometryType: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)

    func didChangeAccessoryState(enabled: Bool)

    func didReceiveWrongPincode()
}

protocol PinSetupPresenterProtocol: class {
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

protocol PinSetupInteractorInputProtocol: class {
    func process(pin: String)
    func change(pin: String)
}

extension PinSetupInteractorInputProtocol {
    func change(pin: String) {
        process(pin: pin)
    }
}

protocol PinSetupInteractorOutputProtocol: class {
    func didSavePin()
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void)
    func didChangeState(from: PinSetupInteractor.PinSetupState)
    func didReceiveConfigError(_ error: Error)
}

extension PinSetupInteractorOutputProtocol {
    func didReceiveConfigError(_ error: Error) { }
}

protocol PinSetupWireframeProtocol: AlertPresentable, ErrorPresentable {
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
