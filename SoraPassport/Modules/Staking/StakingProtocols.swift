/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol StakingViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: ComingSoonViewModel)
}

protocol StakingPresenterProtocol: class {
    func setup(preferredLocalizations languages: [String]?)
    func openLink(url: URL?)
}

protocol StakingInteractorInputProtocol: class {

}

protocol StakingInteractorOutputProtocol: class {

}

protocol StakingWireframeProtocol: WebPresentable {

}

protocol StakingViewFactoryProtocol: class {
	static func createView() -> StakingViewProtocol?
}
