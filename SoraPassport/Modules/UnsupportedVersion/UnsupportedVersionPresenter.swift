/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class UnsupportedVersionPresenter {
    weak var view: UnsupportedVersionViewProtocol?
    var wireframe: UnsupportedVersionWireframeProtocol!
    var interactor: UnsupportedVersionInteractorInputProtocol!

    let supportedVersionData: SupportedVersionData

    var logger: LoggerProtocol?

    init(supportedVersionData: SupportedVersionData) {
        self.supportedVersionData = supportedVersionData
    }
}

extension UnsupportedVersionPresenter: UnsupportedVersionPresenterProtocol {
    func setup() {
        let viewModel = UnsupportedVersionViewModel(title: R.string.localizable.unsupportedTitle(),
                                                    message: R.string.localizable.unsupportedMessage(),
                                                    icon: R.image.iconAppUpdate(),
                                                    actionTitle: R.string.localizable.unsupportedAction())
        view?.didReceive(viewModel: viewModel)
    }

    func performAction() {
        if let url = supportedVersionData.updateUrl {
            if !wireframe.open(url: url) {
                wireframe.present(message: R.string.localizable.urlNoAppErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        } else {
            logger?.warning("Update application url is empty")
        }
    }
}

extension UnsupportedVersionPresenter: UnsupportedVersionInteractorOutputProtocol {}
