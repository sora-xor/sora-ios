/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraCrypto
import RobinHood

final class ReputationViewFactory: ReputationViewFactoryProtocol {
	static func createView() -> ReputationViewProtocol? {
        let view = ReputationViewController(nib: R.nib.reputationViewController)
        let presenter = ReputationPresenter(votesFormatter: NumberFormatter.vote,
                                            integerFormatter: NumberFormatter.anyInteger)
        let interactor = ReputationInteractor(customerDataProviderFacade: CustomerDataProviderFacade.shared)
        let wireframe = ReputationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.logger = Logger.shared

        return view
	}
}
