import Foundation

class PinChangePresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var interactor: PinSetupInteractorInputProtocol!
    var wireframe: PinSetupWireframeProtocol!

    func start() {
        view?.didChangeAccessoryState(enabled: false)
    }

    func activateBiometricAuth() {}

    func cancel() {
        wireframe.dismiss(from: view)
    }

    func submit(pin: String) {
        wireframe.showPinUpdatedNotify(from: view) {
            self.interactor.change(pin: pin)
        }
    }

    var isChangeMode: Bool {
        return true
    }
}

extension PinChangePresenter: PinSetupInteractorOutputProtocol {
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void) {

        DispatchQueue.main.async { [weak self] in
            self?.view?.didRequestBiometryUsage(biometryType: type, completionBlock: completionBlock)
        }

    }

    func didSavePin() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.dismiss(from: self?.view)
        }
    }

    func didChangeState(from: PinSetupInteractor.PinSetupState) {}
}
