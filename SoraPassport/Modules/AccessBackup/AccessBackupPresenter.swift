/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class AccessBackupPresenter {
    weak var view: AccessBackupViewProtocol?
    var interactor: AccessBackupInteractorInputProtocol!
    var wireframe: AccessBackupWireframeProtocol!

    var phrase: String?
}

extension AccessBackupPresenter: AccessBackupPresenterProtocol {
    func viewIsReady() {
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

        let source = TextSharingSource(message: phrase,
                                       subject: R.string.localizable.accessBackupSharingSubject())

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
            switch interactorError {
            case .loading:
                wireframe.present(message: R.string.localizable.accessBackupErrorMessage(),
                                  title: R.string.localizable.accessBackupLoadErrorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }
}
