/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol PolkaswapViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ComingSoonViewModel)
}

protocol PolkaswapPresenterProtocol: class {
    func setup(preferredLocalizations languages: [String]?)
    func openLink(url: URL?)
}

protocol PolkaswapInteractorInputProtocol: class {

}

protocol PolkaswapInteractorOutputProtocol: class {

}

protocol PolkaswapWireframeProtocol: WebPresentable {

}

protocol PolkaswapViewFactoryProtocol: class {
	static func createView() -> PolkaswapViewProtocol?
}
