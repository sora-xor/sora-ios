/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol StartupViewProtocol: ControllerBackedProtocol {
    func didUpdate(title: String, subtitle: String)
}

protocol StartupPresenterProtocol: class {
    func viewIsReady()
}

enum StartupInteratorState {
    case initial
    case verifying
    case waitingRetry
    case completed
}

protocol StartupInteractorInputProtocol: class {
    var state: StartupInteratorState { get }

    func verify()
}

protocol StartupInteractorOutputProtocol: class {
    func didDecideOnboarding()
    func didDecidePincodeSetup()
    func didDecideMain()
    func didChangeState()
}

protocol StartupWireframeProtocol: class {
    func showOnboarding(from view: StartupViewProtocol?)
    func showMain(from view: StartupViewProtocol?)
    func showPincodeSetup(from view: StartupViewProtocol?)
}

protocol StartupViewFactoryProtocol: class {
	static func createView() -> StartupViewProtocol?
}
