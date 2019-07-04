/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol HelpViewProtocol: ControllerBackedProtocol {
    var leadingItemLayoutMetadata: HelpItemLayoutMetadata { get }
    var normalItemLayoutMetadata: HelpItemLayoutMetadata { get }
    var supportLayoutMetadata: PosterLayoutMetadata { get }

    func didReceive(supportItem: PosterViewModelProtocol)
    func didLoad(viewModels: [HelpViewModelProtocol])
}

protocol HelpPresenterProtocol: class {
    func viewIsReady()
    func contactSupport()
}

protocol HelpInteractorInputProtocol: class {
	func setup()
}

protocol HelpInteractorOutputProtocol: class {
    func didReceive(helpItems: [HelpItemData])
    func didReceiveHelpDataProvider(error: Error)
}

protocol HelpWireframeProtocol: ErrorPresentable, AlertPresentable, EmailPresentable {}

protocol HelpViewFactoryProtocol: class {
	static func createView() -> HelpViewProtocol?
}
