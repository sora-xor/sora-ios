/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class HelpViewFactory: HelpViewFactoryProtocol {
	static func createView() -> HelpViewProtocol? {
        let helpDataProvider = InformationDataProviderFacade.shared.helpDataProvider

        let helpViewModelFactory = HelpViewModelFactory()

        let view = HelpViewController(nib: R.nib.helpViewController)

        let email = ApplicationConfig.shared.supportEmail
        let supportDetails = R.string.localizable.helpSupportDetails(email)
        let supportData = SupportData(title: R.string.localizable.helpSupportTitle(),
                                      subject: "",
                                      details: supportDetails,
                                      email: ApplicationConfig.shared.supportEmail)

        let highlightAttributes = [NSAttributedString.Key.foregroundColor: SupportViewStyle.highlightColor]
        let supportEmailDecorator = HighlightingAttributedStringDecorator(pattern: email,
                                                                          attributes: highlightAttributes)
        let supportViewModelFactory = PosterViewModelFactory(detailsDecorator: supportEmailDecorator)
        let presenter = HelpPresenter(helpViewModelFactory: helpViewModelFactory,
                                      supportViewModelFactory: supportViewModelFactory,
                                      supportData: supportData)
        let interactor = HelpInteractor(helpDataProvider: helpDataProvider)
        let wireframe = HelpWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.logger = Logger.shared

        return view
	}
}
