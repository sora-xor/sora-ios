/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class ScreenAuthorizationPresenter {
    weak var view: PinSetupViewProtocol?
    var wireframe: ScreenAuthorizationWireframeProtocol!
    var interactor: LocalAuthInteractorInputProtocol!
    
}

extension ScreenAuthorizationPresenter: PinSetupPresenterProtocol {
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
}

extension ScreenAuthorizationPresenter: LocalAuthInteractorOutputProtocol {
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
            self?.view?.didReceiveWrongPincode()
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
