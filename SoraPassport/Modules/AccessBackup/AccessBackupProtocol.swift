/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol AccessBackupViewProtocol: ControllerBackedProtocol {
    func didReceiveBackup(phrase: String)
}

protocol AccessBackupPresenterProtocol: class {
    func viewIsReady()
    func activateSharing()
    func activateNext()
}

protocol AccessBackupInteractorInputProtocol: class {
    func load()
}

protocol AccessBackupInteractorOutputProtocol: class {
    func didLoad(mnemonicPhrase: String)
    func didReceive(error: Error)
}

enum AccessBackupInteractorError: Error {
    case loading
}

protocol AccessBackupWireframeProtocol: SharingPresentable, AlertPresentable, ErrorPresentable {
    func showNext(from view: AccessBackupViewProtocol?)
}

protocol AccessBackupViewFactoryProtocol: class {
    static func createView() -> AccessBackupViewProtocol?
}
