/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class CurrencyPresenter {
	weak var view: CurrencyViewProtocol?
	var interactor: CurrencyInteractorInputProtocol!
	var wireframe: CurrencyWireframeProtocol!

    private(set) var viewModels: [SelectionListViewModel] = []

    private(set) var currencies: [CurrencyItemData]?
    private(set) var selectedCurrency: CurrencyItemData?

    var logger: LoggerProtocol?

    func updateViewModels() {
        guard let currencies = currencies else {
            return
        }

        guard let selectedCurrency = selectedCurrency else {
            return
        }

        viewModels = currencies.map { currency in
            let title = R.string.localizable.currencyItemTitle(currency.name, currency.symbol)
            let isSelected = currency.code == selectedCurrency.code
            return SelectionListViewModel(title: title, isSelected: isSelected)
        }

        view?.didReload()
    }
}

extension CurrencyPresenter: CurrencyPresenterProtocol {
    func viewIsReady() {
        interactor.setup()
    }

    var numberOfItems: Int {
        return viewModels.count
    }

    func item(at index: Int) -> SelectionListViewModelProtocol {
        return viewModels[index]
    }

    func selectItem(at index: Int) {
        guard !viewModels[index].isSelected else {
            return
        }

        guard let currencies = currencies else {
            return
        }

        if let currentSelectedViewModel = viewModels.first(where: { $0.isSelected }) {
            currentSelectedViewModel.isSelected = false
        }

        viewModels[index].isSelected = true

        self.selectedCurrency = currencies[index]
        interactor.replace(selectedCurrency: currencies[index])
    }
}

extension CurrencyPresenter: CurrencyInteractorOutputProtocol {
    func didLoad(currencies: [CurrencyItemData]) {
        self.currencies = currencies
        updateViewModels()
    }

    func didReceiveCurrencyDataProvider(error: Error) {
        logger?.error("Did receive currency data provider error \(error)")
    }

    func didLoad(selectedCurrency: CurrencyItemData) {
        if self.selectedCurrency != selectedCurrency {
            self.selectedCurrency = selectedCurrency
            updateViewModels()
        }
    }

    func didReceiveSelectedCurrencyDataProvider(error: Error) {
        logger?.error("Did receive selected currency data provider error \(error)")
    }
}
