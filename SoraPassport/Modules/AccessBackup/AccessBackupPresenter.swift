/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

final class AccessBackupPresenter {
    weak var view: AccessBackupViewProtocol?
    var interactor: AccessBackupInteractorInputProtocol!
    var wireframe: AccessBackupWireframeProtocol!

    var phrase: String?
}

extension AccessBackupPresenter: AccessBackupPresenterProtocol {
    func setup() {
        guard let phrase = phrase else {
            interactor.load()
            return
        }

        view?.didReceiveBackup(phrase: phrase)
    }

    func activateSharing() {
        guard let phrase = phrase else {
            return
        }

        let languages = localizationManager?.preferredLocalizations
        let subject = R.string.localizable
            .commonPassphraseSharingSubject(preferredLanguages: languages)
        let source = TextSharingSource(message: phrase,
                                       subject: subject)

        wireframe.share(source: source, from: view, with: nil)
    }

    func activateNext() {
        wireframe.showNext(from: view)
    }
}

extension AccessBackupPresenter: AccessBackupInteractorOutputProtocol {
    func didLoad(mnemonicPhrase: String) {
        phrase = mnemonicPhrase
        view?.didReceiveBackup(phrase: mnemonicPhrase)
    }

    func didReceive(error: Error) {
        if let interactorError = error as? AccessBackupInteractorError {
            let languages = localizationManager?.preferredLocalizations
            switch interactorError {
            case .loading:
                wireframe.present(message: R.string.localizable
                    .accessBackupErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable
                                    .accessBackupLoadErrorTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: languages),
                                  from: view)
            }
        }
    }
}

extension AccessBackupPresenter: Localizable {
    func applyLocalization() {}
}
