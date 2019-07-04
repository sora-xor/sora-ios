/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol LocalAuthInteractorInputProtocol: class {
    var allowManualBiometryAuth: Bool { get }

    func startAuth()
    func process(pin: String)
}

protocol LocalAuthInteractorOutputProtocol: class {
    func didEnterWrongPincode()
    func didChangeState(from state: LocalAuthInteractor.LocalAuthState)
    func didCompleteAuth()
    func didUnexpectedFail()
}
