/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol AccessRestoreViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveView(model: AccessRestoreViewModelProtocol)
}

protocol AccessRestorePresenterProtocol: class {
    func load()
    func activateAccessRestoration()
}

protocol AccessRestoreInteractorInputProtocol: class {
    func restoreAccess(phrase: [String])
}

enum AccessRestoreInteractorError: Error {
    case documentMissing
}

protocol AccessRestoreInteractorOutputProtocol: class {
    func didRestoreAccess(from phrase: [String])
    func didReceiveRestoreAccess(error: Error)
}

protocol AccessRestoreWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showNext(from view: AccessRestoreViewProtocol?)
}

protocol AccessRestoreViewFactoryProtocol: class {
    static func createView() -> AccessRestoreViewProtocol?
}

protocol AccessRestoreViewModelProtocol: class {
    var phrase: String { get }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool
}
