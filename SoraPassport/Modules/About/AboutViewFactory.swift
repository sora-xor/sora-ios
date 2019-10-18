/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class AboutViewFactory: AboutViewFactoryProtocol {
    static func createView() -> AboutViewProtocol? {

        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let legal = LegalData(termsUrl: config.termsURL, privacyPolicyUrl: config.privacyPolicyURL)

        let email = ApplicationConfig.shared.supportEmail
        let supportDetails = R.string.localizable.helpSupportDetails(email)
        let supportData = SupportData(title: R.string.localizable.helpSupportTitle(),
                                      subject: "",
                                      details: supportDetails,
                                      email: ApplicationConfig.shared.supportEmail)

        let about = AboutData(version: config.version,
                              opensourceUrl: config.opensourceURL,
                              legal: legal,
                              writeUs: supportData)

        let view = AboutViewController(nib: R.nib.aboutViewController)
        let presenter = AboutPresenter(about: about)
        let wireframe = AboutWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
