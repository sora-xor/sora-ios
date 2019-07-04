/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class AccessRestorePresenter {
    static let maxMnemonicLength: UInt = 150

    weak var view: AccessRestoreViewProtocol?
    var interactor: AccessRestoreInteractorInputProtocol!
    var wireframe: AccessRestoreWireframeProtocol!

    var model: AccessRestoreViewModelProtocol =
        AccessRestoreViewModel(phrase: "",
                               characterSet: CharacterSet.englishMnemonic,
                               maxLength: AccessRestorePresenter.maxMnemonicLength)
}

extension AccessRestorePresenter: AccessRestorePresenterProtocol {
    func load() {
        view?.didReceiveView(model: model)
    }

    func activateAccessRestoration() {
        view?.didStartLoading()
        interactor.restoreAccess(phrase: model.phrase.components(separatedBy: CharacterSet.wordsSeparator))
    }
}

extension AccessRestorePresenter: AccessRestoreInteractorOutputProtocol {
    func didRestoreAccess(from phrase: [String]) {
        view?.didStopLoading()
        wireframe.showNext(from: view)
    }

    func didReceiveRestoreAccess(error: Error) {
        view?.didStopLoading()

        if wireframe.present(error: error, from: view) {
            return
        }

        wireframe.present(message: R.string.localizable.accessRestorePhraseErrorMessage(),
                          title: R.string.localizable.errorTitle(),
                          closeAction: R.string.localizable.close(),
                          from: view)
    }
}
