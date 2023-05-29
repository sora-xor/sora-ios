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
        interactor.startAuth()
    }

    func cancel() {
        wireframe.showAuthorizationCompletion(with: false)
    }

    func activateBiometricAuth() {
        interactor.startAuth()
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
