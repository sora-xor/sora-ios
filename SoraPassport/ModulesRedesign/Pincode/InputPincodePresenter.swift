import Foundation
import SoraUIKit

enum InputMode {
    case verify
    case create
    case confirm
    
    var title: String {
        switch self {
        case .confirm: return R.string.localizable.pincodeConfirmYourPinCode(preferredLanguages: .currentLocale).capitalized
        case .create: return R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized
        case .verify: return R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized
        }
    }
}

class InputPincodePresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var wireframe: PinSetupWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
    var isNeedUpdateTo6Symbols: Bool = false
    let formatter = DateComponentsFormatter()
    
    public var mode: InputMode = .verify {
        didSet {
            view?.setupTitleLabel(text: mode.title)
            view?.resetTitleColor()
        }
    }
    
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
        interactor.getPinCodeCount()

        if let date = interactor.getInputBlockDate(), date.timeIntervalSinceNow > 0 {
            view?.blockUserInputUntil(date: date)
            return
        } else {
            mode = .verify
        }

        view?.didChangeAccessoryState(enabled: interactor.allowManualBiometryAuth)
        interactor.startAuth()
    }

    func cancel() {}

    func activateBiometricAuth() {
        interactor.startAuth()
    }

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
    
    func updatePinButtonTapped() {
        mode = .create
        inputedPinCode = ""
        view?.updatePinCodeSymbolsCount(with: 6)
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
        
        if inputedPinCode.count == 6, mode == .verify {
            interactor.process(pin: inputedPinCode)
            return
        }
        
        if !savedPinCode.isEmpty, savedPinCode == inputedPinCode {
            interactor.updatePin(pin: savedPinCode) {
                self.wireframe.showMain(from: self.view)
            }
            return
        }
        
        if !savedPinCode.isEmpty, savedPinCode != inputedPinCode, inputedPinCode.count == 6 {
            view?.animateWrongInputError() { [weak self] _ in
                self?.savedPinCode = ""
                self?.inputedPinCode = ""
                self?.mode = .create
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

extension InputPincodePresenter: LocalAuthInteractorOutputProtocol {

    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.animateWrongInputError() { [weak self] _ in
                self?.inputedPinCode = ""
                self?.mode = .verify
            }
        }
    }

    func blockUserInputUntil(date: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.blockUserInputUntil(date: date)
        }
    }

    func reachedLastChancePinInput() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.showLastChanceAlert()
        }
    }

    func didChangeState(from state: LocalAuthInteractor.LocalAuthState) {}
    
    func didCompleteAuth() {
        DispatchQueue.main.async {
            guard self.isNeedUpdateTo6Symbols else {
                self.wireframe.showMain(from: self.view)
                return
            }

            self.mode = .create
            self.view?.showUpdatePinRequestView()
        }
    }

    func didUnexpectedFail() {
        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showSignup(from: self?.view)
        }
    }

    func setupPinCodeSymbols(with count: Int) {
        isNeedUpdateTo6Symbols = count == 4
        view?.updatePinCodeSymbolsCount(with: count)
    }
}
