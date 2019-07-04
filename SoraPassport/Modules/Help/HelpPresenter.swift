/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum HelpPresenterError: Error {
    case unexpectedEmptyLeadingMetadata
    case unexpectedEmptyNormalMetadata
}

final class HelpPresenter {
	weak var view: HelpViewProtocol?
	var interactor: HelpInteractorInputProtocol!
	var wireframe: HelpWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var helpViewModelFactory: HelpViewModelFactoryProtocol
    private(set) var supportViewModelFactory: PosterViewModelFactoryProtocol
    private(set) var supportData: SupportData

    init(helpViewModelFactory: HelpViewModelFactoryProtocol,
         supportViewModelFactory: PosterViewModelFactoryProtocol,
         supportData: SupportData) {
        self.helpViewModelFactory = helpViewModelFactory
        self.supportViewModelFactory = supportViewModelFactory
        self.supportData = supportData
    }

    private func updateView(with helpItems: [HelpItemData]) throws {
        guard let leadingMetadata = view?.leadingItemLayoutMetadata else {
            throw HelpPresenterError.unexpectedEmptyLeadingMetadata
        }

        guard let normalMetadata = view?.normalItemLayoutMetadata else {
            throw HelpPresenterError.unexpectedEmptyNormalMetadata
        }

        var viewModels: [HelpViewModelProtocol] = []

        for (index, helpItem) in helpItems.enumerated() {
            let metadata = index == 0 ? leadingMetadata : normalMetadata

            let viewModel = helpViewModelFactory.createViewModel(from: helpItem,
                                                                 layoutMetadata: metadata)
            viewModels.append(viewModel)
        }

        view?.didLoad(viewModels: viewModels)
    }

    private func updateSupportView() {
        if let view = view {
            let viewModel = supportViewModelFactory.createViewModel(from: supportData.title,
                                                                    details: supportData.details,
                                                                    layoutMetadata: view.supportLayoutMetadata)
            view.didReceive(supportItem: viewModel)
        }
    }
}

extension HelpPresenter: HelpPresenterProtocol {
    func viewIsReady() {
        updateSupportView()
        interactor.setup()
    }

    func contactSupport() {
        if let view = view {
            let message = SocialMessage(body: nil,
                                        subject: supportData.subject,
                                        recepients: [supportData.email])
            wireframe.writeEmail(with: message,
                                 from: view,
                                 completionHandler: nil)
        }
    }
}

extension HelpPresenter: HelpInteractorOutputProtocol {
    func didReceive(helpItems: [HelpItemData]) {
        do {
            try updateView(with: helpItems)
        } catch {
            logger?.error("Did receive update view error \(error)")
        }

    }

    func didReceiveHelpDataProvider(error: Error) {
        logger?.error("Did receive help data provider error error \(error)")
    }
}
