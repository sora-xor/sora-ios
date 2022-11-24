/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol LocalAuthInteractorInputProtocol: AnyObject {
    var allowManualBiometryAuth: Bool { get }

    func startAuth()
    func process(pin: String)
    func getPinCodeCount()
    func getInputBlockDate() -> Date?
}

protocol LocalAuthInteractorOutputProtocol: AnyObject {
    func didEnterWrongPincode()
    func blockUserInputUntil(date: Date)
    func reachedLastChancePinInput()
    func didChangeState(from state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
    func setupPinCodeSymbols(with count: Int)
}

extension LocalAuthInteractorOutputProtocol {
    func setupPinCodeSymbols(with count: Int) {}
}
