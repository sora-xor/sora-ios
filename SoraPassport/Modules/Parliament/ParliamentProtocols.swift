/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol ParliamentViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ComingSoonViewModel)
}

protocol ParliamentPresenterProtocol: class {
    func setup(preferredLocalizations languages: [String]?)
    func activateReferenda()
}

protocol ParliamentInteractorInputProtocol: class {

}

protocol ParliamentInteractorOutputProtocol: class {

}

protocol ParliamentWireframeProtocol: class {
    func showReferendaView(from view: ParliamentViewProtocol?)
}

protocol ParliamentViewFactoryProtocol: class {
	static func createView() -> ParliamentViewProtocol?
}
