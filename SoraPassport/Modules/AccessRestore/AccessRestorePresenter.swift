/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

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

        let locale = localizationManager?.selectedLocale

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        let languages = locale?.rLanguages

        wireframe.present(message: R.string.localizable
            .accessRestorePhraseErrorMessage(preferredLanguages: languages),
                          title: R.string.localizable
                            .commonErrorGeneralTitle(preferredLanguages: languages),
                          closeAction: R.string.localizable
                            .commonClose(preferredLanguages: languages),
                          from: view)
    }
}

extension AccessRestorePresenter: Localizable {
    func applyLocalization() {}
}
