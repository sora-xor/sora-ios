/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import Cuckoo
import RobinHood
@testable import SoraPassport

class CurrencyInteractorTests: NetworkBaseTests {

    func testSuccessfullSetup() {
        // given
        CurrencyFetchMock.register(mock: .success,
                                   projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let interactor = createInteractor()
        let presenter = CurrencyPresenter()
        let view = MockCurrencyViewProtocol()

        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReload().then { _ in
                expectation.fulfill()
            }
        }

        // when
        interactor.setup()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        verify(view, times(1)).didReload()

        guard presenter.viewModels.first(where: { $0.isSelected }) != nil else {
            XCTFail()
            return
        }
    }

    // MARK: Private

    func createInteractor() -> CurrencyInteractor {
        let requestSigner = createDummyRequestSigner()

        let informationFacade = InformationDataProviderFacade()
        informationFacade.coreDataCacheFacade = CoreDataCacheTestFacade()
        informationFacade.requestSigner = requestSigner

        let currencyDataProvider = informationFacade.currencyDataProvider
        let selectedCurrencyDataProvider = SelectedCurrencyDataProvider(currenciesDataProvider: currencyDataProvider,
                                                                        settingsManager: InMemorySettingsManager(),
                                                                        settingsKey: SettingsKey.selectedCurrency.rawValue,
                                                                        defaultCurrencyItem: ApplicationConfig.shared.defaultCurrency,
                                                                        updateTrigger: DataProviderEventTrigger.onNone)

        return CurrencyInteractor(currencyDataProvider: currencyDataProvider,
                                  selectedCurrencyDataProvider: selectedCurrencyDataProvider)
    }
}
