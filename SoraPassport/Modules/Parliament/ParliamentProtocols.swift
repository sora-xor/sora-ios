/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ParliamentViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ComingSoonViewModel)
}

protocol ParliamentPresenterProtocol: class {
    func setup(preferredLocalizations languages: [String]?)
    func activateReferenda()
    func openLink(url: URL?)
}

protocol ParliamentInteractorInputProtocol: class {

}

protocol ParliamentInteractorOutputProtocol: class {

}

protocol ParliamentWireframeProtocol: WebPresentable {
    func showReferendaView(from view: ParliamentViewProtocol?)
}

protocol ParliamentViewFactoryProtocol: class {
	static func createView() -> ParliamentViewProtocol?
}
