/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import SoraKeystore
import RobinHood
@testable import SoraPassport

class SelectedCurrencyDataProviderTests: XCTestCase {
    var cacheFacade: CoreDataCacheFacadeProtocol!

    override func setUp() {
        super.setUp()

        cacheFacade = CoreDataCacheTestFacade()
    }

    func testInitialValueGuaranteeWhenSourceReachable() {
        let maxTriggerRawValue = DataProviderEventTrigger.onAll.rawValue

        for rawValue in 0...maxTriggerRawValue {
            performTestInitialValueGuaranteeWhenSourceReachableWithUpdateTrigger(DataProviderEventTrigger(rawValue: rawValue))
        }
    }

    func testInitialValueGuaranteeWhenSourceNotReachable() {
        let maxTriggerRawValue = DataProviderEventTrigger.onAll.rawValue

        for rawValue in 0...maxTriggerRawValue {
            performTestInitialValueGuaranteeWhenSourceNotReachableWithUpdateTrigger(DataProviderEventTrigger(rawValue: rawValue))
        }
    }

    func testInitialValueMatchesLocale() {
        // given
        let locale = Locale(identifier: "en_US")

        var currencyData = createRandomCurrencyData()
        var topics = currencyData.topics
        topics[String(topics.count - 1)]?.code = locale.currencyCode!
        currencyData.topics = topics

        let source: AnySingleValueProviderSource<CurrencyData> = createSingleValueSourceMock(base: self, returns: currencyData)

        let dataProvider = createSelectedCurrencyDataProvider(from: source,
                                                              defaultCurrency: createRandomCurrencyItem(),
                                                              settingsManager: InMemorySettingsManager(),
                                                              locale: locale)

        let expectation = XCTestExpectation()

        var receivedChanges: [DataProviderChange<CurrencyItemData>]?

        let changesBlock = { (changes: [DataProviderChange<CurrencyItemData>]) -> Void in
            receivedChanges = changes

            expectation.fulfill()
        }

        let failBlock = { (error: Error) -> Void in
            XCTFail()

            expectation.fulfill()
        }

        // when

        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: failBlock,
                                      options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let changes = receivedChanges else {
            XCTFail()
            return
        }

        guard changes.count == 1 else {
            return
        }

        switch changes[0] {
        case .insert(let newItem):
            XCTAssertEqual(newItem.code, locale.currencyCode)
        default:
            XCTFail()
        }
    }

    func testRefreshWhenHasNoCurrencyItemUpdate() {
        // given
        let currencyData = createRandomCurrencyData()
        let settings = InMemorySettingsManager()
        let dataProvider = createSelectedCurrencyDataProvider(from: currencyData,
                                                              defaultCurrency: createRandomCurrencyItem(),
                                                              settingsManager: settings,
                                                              updateTrigger: DataProviderEventTrigger.onNone)

        let initializationExpectation = XCTestExpectation()
        let updateExpectation = XCTestExpectation()

        var optionalInitializationChanges: [DataProviderChange<CurrencyItemData>]?
        var optionalUpdateChanges: [DataProviderChange<CurrencyItemData>]?

        let changesBlock = { (changes: [DataProviderChange<CurrencyItemData>]) -> Void in
            if optionalInitializationChanges == nil {
                optionalInitializationChanges = changes
                initializationExpectation.fulfill()
                return
            }

            if optionalUpdateChanges == nil {
                optionalUpdateChanges = changes
                updateExpectation.fulfill()
                return
            }
        }

        let failBlock = { (error: Error) -> Void in
            XCTFail()
        }

        // when

        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: failBlock,
                                      options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))

        wait(for: [initializationExpectation], timeout: Constants.expectationDuration)

        dataProvider.refreshCache()

        wait(for: [updateExpectation], timeout: Constants.expectationDuration)

        // then

        guard let currentItem = settings.value(of: CurrencyItemData.self, for: SettingsKey.selectedCurrency.rawValue) else {
            XCTFail()
            return
        }

        guard let initializationChanges = optionalInitializationChanges else {
            XCTFail()
            return
        }

        guard initializationChanges.count == 1 else {
            XCTFail()
            return
        }

        switch initializationChanges[0] {
        case .insert(let item):
            XCTAssertEqual(item, currentItem)
        default:
            XCTFail()
        }

        guard let updateChanges = optionalUpdateChanges else {
            XCTFail()
            return
        }

        guard updateChanges.count == 0 else {
            XCTFail()
            return
        }
    }

    func testReplaceCurrentItem() {
        // given

        let currencyData = createRandomCurrencyData()
        let settings = InMemorySettingsManager()
        let dataProvider = createSelectedCurrencyDataProvider(from: currencyData,
                                                              defaultCurrency: createRandomCurrencyItem(),
                                                              settingsManager: settings,
                                                              updateTrigger: DataProviderEventTrigger.onNone)

        let initializationExpectation = XCTestExpectation()
        let updateExpectation = XCTestExpectation()

        var optionalInitializationChanges: [DataProviderChange<CurrencyItemData>]?
        var optionalUpdateChanges: [DataProviderChange<CurrencyItemData>]?

        let changesBlock = { (changes: [DataProviderChange<CurrencyItemData>]) -> Void in
            if optionalInitializationChanges == nil {
                optionalInitializationChanges = changes
                initializationExpectation.fulfill()
                return
            }

            if optionalUpdateChanges == nil {
                optionalUpdateChanges = changes
                updateExpectation.fulfill()
                return
            }
        }

        let failBlock = { (error: Error) -> Void in
            XCTFail()
        }

        // when

        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: failBlock,
                                      options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))

        wait(for: [initializationExpectation], timeout: Constants.expectationDuration)

        let newItem = createRandomCurrencyItem()
        dataProvider.replaceModel(with: newItem)

        wait(for: [updateExpectation], timeout: Constants.expectationDuration)

        // then

        guard let updateChanges = optionalUpdateChanges else {
            XCTFail()
            return
        }

        guard updateChanges.count == 1 else {
            XCTFail()
            return
        }

        switch updateChanges[0] {
        case .update(let currentItem):
            XCTAssertEqual(newItem, currentItem)
        default:
            XCTFail()
        }
    }

    func testFetchWhenCached() {
        // given
        let currencyData = createRandomCurrencyData()
        let settings = InMemorySettingsManager()
        let dataProvider = createSelectedCurrencyDataProvider(from: currencyData,
                                                              defaultCurrency: createRandomCurrencyItem(),
                                                              settingsManager: settings,
                                                              updateTrigger: DataProviderEventTrigger.onNone)

        let cachedItem = createRandomCurrencyItem()
        settings.set(value: cachedItem, for: SettingsKey.selectedCurrency.rawValue)

        let expectation = XCTestExpectation()

        // when
        let operation = dataProvider.fetch { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let fetchResult = operation.result else {
            XCTFail()
            return
        }

        switch fetchResult {
        case .success(let item):
            XCTAssertEqual(cachedItem, item)
        default:
            XCTFail()
        }
    }

    func testFetchWhenNotCached() {
        // given
        let currencyData = createRandomCurrencyData()
        let settings = InMemorySettingsManager()
        let dataProvider = createSelectedCurrencyDataProvider(from: currencyData,
                                                              defaultCurrency: createRandomCurrencyItem(),
                                                              settingsManager: settings,
                                                              updateTrigger: DataProviderEventTrigger.onNone)

        let expectation = XCTestExpectation()

        // when
        let operation = dataProvider.fetch { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let fetchResult = operation.result else {
            XCTFail()
            return
        }

        switch fetchResult {
        case .error:
            XCTFail()
        default:
            break
        }
    }

    // MARK: Test Templates

    func performTestInitialValueGuaranteeWhenSourceNotReachableWithUpdateTrigger(_ updateTrigger: DataProviderTriggerProtocol) {
        let source: AnySingleValueProviderSource<CurrencyData> = createSingleValueSourceMock(base: self, returns: NetworkBaseError.unexpectedResponseObject)

        let dataProvider = createSelectedCurrencyDataProvider(from: source,
                                                              defaultCurrency: createRandomCurrencyItem(),
                                                              settingsManager: InMemorySettingsManager(),
                                                              updateTrigger: updateTrigger)

        performTestInitialValueGuaranteeWithDataProvider(dataProvider)
    }

    func performTestInitialValueGuaranteeWhenSourceReachableWithUpdateTrigger(_ updateTrigger: DataProviderTriggerProtocol) {
        let defaultCurrencyItem = createRandomCurrencyItem()
        let dataProvider = createSelectedCurrencyDataProvider(from: createEmptyCurrencyData(),
                                                              defaultCurrency: defaultCurrencyItem,
                                                              settingsManager: InMemorySettingsManager(),
                                                              updateTrigger: updateTrigger)

        performTestInitialValueGuaranteeWithDataProvider(dataProvider)
    }

    func performTestInitialValueGuaranteeWithDataProvider(_ dataProvider: SelectedCurrencyDataProvider) {
        // given

        let expectation = XCTestExpectation()

        var receivedChanges: [DataProviderChange<CurrencyItemData>]?

        let changesBlock = { (changes: [DataProviderChange<CurrencyItemData>]) -> Void in
            receivedChanges = changes

            expectation.fulfill()
        }

        let failBlock = { (error: Error) -> Void in
            XCTFail()

            expectation.fulfill()
        }

        // when

        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: failBlock,
                                      options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard let changes = receivedChanges else {
            XCTFail()
            return
        }

        guard changes.count == 1 else {
            return
        }

        switch changes[0] {
        case .insert(let newItem):
            XCTAssertEqual(newItem, dataProvider.defaultCurrencyItem)
        default:
            XCTFail()
        }
    }

    // MARK: Private

    private func createSelectedCurrencyDataProvider(from currencyData: CurrencyData,
                                                    defaultCurrency: CurrencyItemData,
                                                    settingsManager: SettingsManagerProtocol,
                                                    updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
                                                    locale: Locale = Locale.current)
        -> SelectedCurrencyDataProvider {
        let source = createSingleValueSourceMock(base: self, returns: currencyData)
        return createSelectedCurrencyDataProvider(from: source,
                                                  defaultCurrency: defaultCurrency,
                                                  settingsManager: settingsManager,
                                                  updateTrigger: updateTrigger,
                                                  locale: locale)
    }

    private func createSelectedCurrencyDataProvider(from source: AnySingleValueProviderSource<CurrencyData>,
                                                    defaultCurrency: CurrencyItemData,
                                                    settingsManager: SettingsManagerProtocol,
                                                    updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
                                                    locale: Locale = Locale.current)
        -> SelectedCurrencyDataProvider {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = cacheFacade
            .createCoreDataCache(domain: UUID().uuidString)

        let currenciesProvider = SingleValueProvider<CurrencyData, CDSingleValue>(targetIdentifier: UUID().uuidString,
                                                                                  source: source,
                                                                                  cache: cache,
                                                                                  updateTrigger: updateTrigger)
        return SelectedCurrencyDataProvider(currenciesDataProvider: currenciesProvider,
                                            settingsManager: settingsManager,
                                            settingsKey: SettingsKey.selectedCurrency.rawValue,
                                            defaultCurrencyItem: defaultCurrency,
                                            updateTrigger: updateTrigger,
                                            locale: locale)
    }
}
