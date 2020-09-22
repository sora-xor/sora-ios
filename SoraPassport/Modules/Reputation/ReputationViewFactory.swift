/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraCrypto
import RobinHood
import SoraFoundation

final class ReputationViewFactory: ReputationViewFactoryProtocol {
	static func createView() -> ReputationViewProtocol? {
        let locale = LocalizationManager.shared.selectedLocale

        let viewModelFactory = ReputationViewModelFactory(timeFormatter: TotalTimeFormatter())
        let reputationDelayFactory = ReputationDelayFactory()

        let votesFormater = NumberFormatter.vote
        votesFormater.locale = locale

        let integerFormatter = NumberFormatter.anyInteger
        integerFormatter.locale = locale

        let view = ReputationViewController(nib: R.nib.reputationViewController)
        let presenter = ReputationPresenter(locale: locale,
                                            viewModelFactory: viewModelFactory,
                                            reputationDelayFactory: reputationDelayFactory,
                                            votesFormatter: votesFormater,
                                            integerFormatter: integerFormatter)
        let interactor = ReputationInteractor(reputationProvider:
            CustomerDataProviderFacade.shared.reputationDataProvider,
                                              reputationDetailsProvider:
            InformationDataProviderFacade.shared.reputationDetailsProvider,
                                              votesProvider:
            CustomerDataProviderFacade.shared.votesProvider)
        let wireframe = ReputationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.locale = locale
        presenter.logger = Logger.shared

        return view
	}
}
