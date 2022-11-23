/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

class LocalAuthPresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var wireframe: PinSetupWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
    var isNeedUpdateTo6Symbols: Bool = false
    let formatter = DateComponentsFormatter()

    func start() {
        interactor.getPinCodeCount()

        if let date = interactor.getInputBlockDate(), date.timeIntervalSinceNow > 0 {
            view?.blockUserInputUntil(date: date)
            return
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
        guard let controller = view?.controller else { return }
        wireframe.showUpdatePinView(from: controller) { [weak self] in
            self?.wireframe.showMain(from: self?.view)
        }
    }
}

extension LocalAuthPresenter: LocalAuthInteractorOutputProtocol {

    func didEnterWrongPincode() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveWrongPincode()
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
