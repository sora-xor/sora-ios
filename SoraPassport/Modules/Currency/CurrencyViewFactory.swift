/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import RobinHood

final class CurrencyViewFactory: CurrencyViewFactoryProtocol {
	static func createView() -> CurrencyViewProtocol? {
        let currencyDataProvider = InformationDataProviderFacade.shared.currencyDataProvider
        let selectedCurrencyDataProvider = SettingsDataProviderFacade.shared.selectedCurrencyDataProvider

        let view = CurrencyViewController(nib: R.nib.selectionListViewController)
        let presenter = CurrencyPresenter()
        let interactor = CurrencyInteractor(currencyDataProvider: currencyDataProvider,
                                            selectedCurrencyDataProvider: selectedCurrencyDataProvider)
        let wireframe = CurrencyWireframe()

        view.listPresenter = presenter
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
	}
}
