import Foundation
import SoraFoundation

class PinSetupPresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var interactor: PinSetupInteractorInputProtocol!
    var wireframe: PinSetupWireframeProtocol!

    func start() {
        view?.didChangeAccessoryState(enabled: false)
    }

    func activateBiometricAuth() {}

    func cancel() {}

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
}

extension PinSetupPresenter: PinSetupInteractorOutputProtocol {
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void) {

        DispatchQueue.main.async { [weak self] in
            self?.view?.didRequestBiometryUsage(biometryType: type, completionBlock: completionBlock)
        }

    }

    func didSavePin() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showMain(from: self?.view)
        }
    }

    func didReceiveConfigError(_ error: Error) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = self.wireframe.present(error: error, from: nil, locale: LocalizationManager.shared.selectedLocale)
        }

    }

    func didChangeState(from: PinSetupInteractor.PinSetupState) {}
}
