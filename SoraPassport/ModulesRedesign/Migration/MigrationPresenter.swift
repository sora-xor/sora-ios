// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

final class MigrationPresenter {
    weak var view: MigrationViewProtocol?
    var wireframe: MigrationWireframe!
    var interactor: MigrationInteractor!

    let email: String
    let locale: Locale

    init(email: String, locale: Locale) {
        self.email = email
        self.locale = locale
    }

    func proceed() {
        interactor.startMigration()
    }

    func retry() {
        view?.resetState()
        wireframe.present(message: R.string.localizable.commonErrorRetry(),
                          title: R.string.localizable.claimErrorTitle(),
                          closeAction: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages),
                          from: view)
    }

    func activateTerms() {
        activateEmail(to: email)
    }

    func activatePrivacy() {
       activateEmail(to: email)
    }
}

private extension MigrationPresenter {
    func activateEmail(to email: String) {
        guard let view = view else {
            return
        }

        let message = SocialMessage(
            body: nil, subject: nil,
            recepients: [email]
        )

        let languages = locale.rLanguages

        if !wireframe.writeEmail(with: message, from: view, completionHandler: nil) {
            wireframe.present(
                message: R.string.localizable.noEmailBoundErrorMessage(preferredLanguages: languages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                from: view
            )
        }
    }
}
