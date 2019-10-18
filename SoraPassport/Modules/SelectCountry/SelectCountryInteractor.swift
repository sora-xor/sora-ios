/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class SelectCountryInteractor {
    weak var presenter: SelectCountryInteractorOutputProtocol!

    let countryProvider: SingleValueProvider<CountryData, CDSingleValue>

    init(countryProvider: SingleValueProvider<CountryData, CDSingleValue>) {
        self.countryProvider = countryProvider
    }

    private func setupDataProvider() {
        let updateBlock: ([DataProviderChange<CountryData>]) -> Void = { [weak self] changes in
            if let change = changes.first {
                switch change {
                case .insert(let item), .update(let item):
                    self?.presenter.didReceive(countries: item.countries)
                case .delete:
                    break
                }
            } else {
                self?.presenter.didReceive(countries: [])
            }
        }

        let failureBlock: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDataProvider(error: error)
        }

        countryProvider.addCacheObserver(self,
                                         deliverOn: .main,
                                         executing: updateBlock,
                                         failing: failureBlock)
    }
}

extension SelectCountryInteractor: SelectCountryInteractorInputProtocol {
    func setup() {
        setupDataProvider()
    }
}
