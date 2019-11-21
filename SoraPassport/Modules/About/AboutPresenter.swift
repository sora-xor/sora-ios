/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class AboutPresenter {
    weak var view: AboutViewProtocol?
    var wireframe: AboutWireframeProtocol!

    let about: AboutData

    init(about: AboutData) {
        self.about = about
    }

    private func show(url: URL) {
        if let view = view {
            wireframe.showWeb(url: url, from: view, style: .automatic)
        }
    }
}

extension AboutPresenter: AboutPresenterProtocol {
    func setup() {
        view?.didReceive(version: about.version)
    }

    func activateOpensource() {
        show(url: about.opensourceUrl)
    }

    func activateTerms() {
        show(url: about.legal.termsUrl)
    }

    func activatePrivacyPolicy() {
        show(url: about.legal.privacyPolicyUrl)
    }

    func activateWriteUs() {
        if let view = view {
            let message = SocialMessage(body: nil,
                                        subject: about.writeUs.subject,
                                        recepients: [about.writeUs.email])
            if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
                wireframe.present(message: R.string.localizable.noEmailBoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }
}
