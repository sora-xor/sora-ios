/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import RobinHood

final class SettingsDataProviderFacade: SettingsDataProviderFacadeProtocol {
    static let shared = SettingsDataProviderFacade()

    lazy var currenciesDataProvider: SingleValueProvider<CurrencyData> =
        InformationDataProviderFacade.shared.currencyDataProvider

    lazy var settingsManager: SettingsManagerProtocol = SettingsManager.shared
    lazy var settingsKey: String = SettingsKey.selectedCurrency.rawValue
    lazy var applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

    lazy private(set) var selectedCurrencyDataProvider: SelectedCurrencyDataProvider = {
        return SelectedCurrencyDataProvider(currenciesDataProvider: currenciesDataProvider,
                                            settingsManager: settingsManager,
                                            settingsKey: settingsKey,
                                            defaultCurrencyItem: applicationConfig.defaultCurrency,
                                            updateTrigger: DataProviderEventTrigger.onAddObserver)
    }()

    let executionQueue: OperationQueue

    private init() {
        executionQueue = OperationQueue()
    }
}
