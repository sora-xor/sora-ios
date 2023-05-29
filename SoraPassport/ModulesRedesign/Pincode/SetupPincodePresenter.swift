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
