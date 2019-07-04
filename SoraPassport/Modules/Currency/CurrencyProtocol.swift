/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol CurrencyViewProtocol: SelectionListViewProtocol {}

protocol CurrencyPresenterProtocol: SelectionListPresenterProtocol {
	func viewIsReady()
}

protocol CurrencyInteractorInputProtocol: class {
	func setup()
    func replace(selectedCurrency: CurrencyItemData)
}

protocol CurrencyInteractorOutputProtocol: class {
    func didLoad(currencies: [CurrencyItemData])
    func didReceiveCurrencyDataProvider(error: Error)

    func didLoad(selectedCurrency: CurrencyItemData)
    func didReceiveSelectedCurrencyDataProvider(error: Error)
}

protocol CurrencyWireframeProtocol: AlertPresentable, ErrorPresentable {}

protocol CurrencyViewFactoryProtocol: class {
	static func createView() -> CurrencyViewProtocol?
}
