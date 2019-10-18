/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class CurrencyInteractor {
	weak var presenter: CurrencyInteractorOutputProtocol?

    private(set) var currencyDataProvider: SingleValueProvider<CurrencyData, CDSingleValue>
    private(set) var selectedCurrencyDataProvider: SelectedCurrencyDataProvider

    init(currencyDataProvider: SingleValueProvider<CurrencyData, CDSingleValue>,
         selectedCurrencyDataProvider: SelectedCurrencyDataProvider) {
        self.currencyDataProvider = currencyDataProvider
        self.selectedCurrencyDataProvider = selectedCurrencyDataProvider
    }

    private func setupSelectedCurrencyDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<CurrencyItemData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let selectedCurrency), .update(let selectedCurrency):
                    self?.presenter?.didLoad(selectedCurrency: selectedCurrency)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveSelectedCurrencyDataProvider(error: error)
        }

        selectedCurrencyDataProvider.addCacheObserver(self,
                                                      deliverOn: .main,
                                                      executing: changesBlock,
                                                      failing: failBlock)
    }

    private func setupCurrencyDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<CurrencyData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let currencyData), .update(let currencyData):
                    self?.handle(optionalCurrencyData: currencyData)
                case .delete:
                    self?.handle(optionalCurrencyData: nil)
                }
            } else {
                self?.handle(optionalCurrencyData: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveCurrencyDataProvider(error: error)
        }

        currencyDataProvider.addCacheObserver(self,
                                              deliverOn: .main,
                                              executing: changesBlock,
                                              failing: failBlock)
    }

    private func handle(optionalCurrencyData: CurrencyData?) {
        guard let currencyData = optionalCurrencyData else {
            presenter?.didLoad(currencies: [])
            return
        }

        let currencyItems = currencyData.sortedItems()

        presenter?.didLoad(currencies: currencyItems)
    }
}

extension CurrencyInteractor: CurrencyInteractorInputProtocol {
    func setup() {
        setupCurrencyDataProvider()
        setupSelectedCurrencyDataProvider()
    }

    func replace(selectedCurrency: CurrencyItemData) {
        selectedCurrencyDataProvider.replaceModel(with: selectedCurrency)
    }
}
