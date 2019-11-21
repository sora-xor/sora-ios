/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import RobinHood

typealias CurrencyItemChange = DataProviderChange<CurrencyItemData>

protocol SelectedCurrencyDataProviderProtocol: SingleValueProviderProtocol {
    func replaceModel(with newModel: Model)
}

final class SelectedCurrencyDataProvider {
    private(set) var currenciesDataProvider: SingleValueProvider<CurrencyData>
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var settingsKey: String
    private(set) var defaultCurrencyItem: CurrencyItemData
    private(set) var updateTrigger: DataProviderTriggerProtocol
    private(set) var synchronizationQueue: DispatchQueue
    private(set) var locale: Locale

    private var lastSyncOperation: Operation?

    private var isInitialized: Bool = false

    private var cacheObservers: [DataProviderObserver<CurrencyItemData>] = []

    init(currenciesDataProvider: SingleValueProvider<CurrencyData>,
         settingsManager: SettingsManagerProtocol,
         settingsKey: String,
         defaultCurrencyItem: CurrencyItemData,
         updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
         serialSyncronizationQueue: DispatchQueue? = nil,
         locale: Locale = NSLocale.current) {

        self.currenciesDataProvider = currenciesDataProvider
        self.settingsManager = settingsManager
        self.settingsKey = settingsKey
        self.defaultCurrencyItem = defaultCurrencyItem
        self.locale = locale

        if let currentSynchronizationQueue = serialSyncronizationQueue {
            self.synchronizationQueue = currentSynchronizationQueue
        } else {
            self.synchronizationQueue = DispatchQueue(
                label: "co.jp.selectedcurrency.provider.queue.\(UUID().uuidString)",
                qos: .default)
        }

        self.updateTrigger = updateTrigger
        self.updateTrigger.delegate = self

        setupCurrenciesDataProvider()

        self.updateTrigger.receive(event: .initialization)
    }

    private func firstMatchingLocale(from currencies: [CurrencyItemData]) -> CurrencyItemData? {
        guard let currencyCode = locale.currencyCode else {
            return currencies.first
        }

        return currencies.first(where: { $0.code == currencyCode }) ?? currencies.first
    }

    private func setupCurrenciesDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<CurrencyData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let currencyData), .update(let currencyData):
                    self?.handleCurrencies(update: currencyData)
                case .delete:
                    self?.handleCurrencies(update: nil)
                }
            } else {
                self?.handleCurrencies(update: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.handleCurrenciesUpdate(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        currenciesDataProvider.addObserver(self,
                                           deliverOn: synchronizationQueue,
                                           executing: changesBlock,
                                           failing: failBlock,
                                           options: options)
    }

    private func updateWaitingInitializationGuaranteeState(with update: CurrencyData?) -> Bool {
        if !isInitialized {
            isInitialized = true

            if update == nil, settingsManager.value(of: CurrencyItemData.self, for: settingsKey) == nil {
                return true
            }
        }

        return false
    }

    private func handleCurrencies(update: CurrencyData?) {
        if update == nil, !isInitialized {
            isInitialized = true
            currenciesDataProvider.refresh()
            return
        }

        isInitialized = true

        let fetchedItems = update?.sortedItems() ?? []

        let saveOperation = createSaveOperation(fetchedCurrencies: fetchedItems,
                                                defaultCurrencyItem: defaultCurrencyItem)

        saveOperation.completionBlock = {
            self.handleSaveOperation(optionalResult: saveOperation.result)
        }

        synchronizeOperation(saveOperation)

        executionQueue.addOperation(saveOperation)
    }

    private func handleCurrenciesUpdate(error: Error) {
        isInitialized = true

        let currentCurrencyItem = settingsManager.value(of: CurrencyItemData.self, for: settingsKey)
        if currentCurrencyItem == nil {
            handleCurrencies(update: nil)
            return
        }

        notifyObservers(with: error)
    }

    private func createSaveOperation(fetchedCurrencies: [CurrencyItemData],
                                     defaultCurrencyItem: CurrencyItemData)
        -> BaseOperation<CurrencyItemChange?> {
        let operation = ClosureOperation<CurrencyItemChange?> {
            let optionalItem = self.settingsManager.value(of: CurrencyItemData.self, for: self.settingsKey)
            guard let currentCurrencyItem = optionalItem else {
                if let newCurrencyItem = self.firstMatchingLocale(from: fetchedCurrencies) {
                    self.settingsManager.set(value: newCurrencyItem, for: self.settingsKey)
                    return .insert(newItem: newCurrencyItem)
                } else {
                    self.settingsManager.set(value: defaultCurrencyItem, for: self.settingsKey)
                    return .insert(newItem: defaultCurrencyItem)
                }
            }

            let optionalFetchedCurrencyItem = fetchedCurrencies.first { $0.code == currentCurrencyItem.code }
            guard let fetchedCurrencyItem = optionalFetchedCurrencyItem else {
                return nil
            }

            if fetchedCurrencyItem == currentCurrencyItem {
                return nil
            }

            self.settingsManager.set(value: fetchedCurrencyItem, for: self.settingsKey)
            return .update(newItem: fetchedCurrencyItem)
        }

        return operation
    }

    private func scheduleReplaceModel(with newModel: Model) {
        let saveOperation = ClosureOperation<CurrencyItemChange?> {
            let currentItem = self.settingsManager.value(of: CurrencyItemData.self, for: self.settingsKey)

            if newModel != currentItem {
                self.settingsManager.set(value: newModel, for: self.settingsKey)
                return .update(newItem: newModel)
            } else {
                return nil
            }
        }

        saveOperation.completionBlock = {
            self.handleSaveOperation(optionalResult: saveOperation.result)
        }

        synchronizeOperation(saveOperation)

        executionQueue.addOperation(saveOperation)
    }

    private func handleSaveOperation(optionalResult: Result<CurrencyItemChange?, Error>?) {
        guard let result = optionalResult else {
            return
        }

        switch result {
        case .success(let optionalUpdate):
            self.synchronizationQueue.async {
                self.notifyObservers(with: optionalUpdate)
            }
        case .failure(let error):
            self.synchronizationQueue.async {
                self.notifyObservers(with: error)
            }
        }
    }

    private func notifyObservers(with update: CurrencyItemChange?) {
        cacheObservers.forEach { (cacheObserver) in
            if cacheObserver.observer != nil,
                (update != nil || cacheObserver.options.alwaysNotifyOnRefresh) {
                dispatchInQueueWhenPossible(cacheObserver.queue) {
                    if let update = update {
                        cacheObserver.updateBlock([update])
                    } else {
                        cacheObserver.updateBlock([])
                    }
                }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        cacheObservers.forEach { (cacheObserver) in
            if cacheObserver.observer != nil, cacheObserver.options.alwaysNotifyOnRefresh {
                dispatchInQueueWhenPossible(cacheObserver.queue) {
                    cacheObserver.failureBlock(error)
                }
            }
        }
    }

    private func synchronizeOperation(_ operation: Operation) {
        if let syncOperation = self.lastSyncOperation, !syncOperation.isFinished {
            operation.addDependency(syncOperation)
        }

        self.lastSyncOperation = operation
    }
}

extension SelectedCurrencyDataProvider: SelectedCurrencyDataProviderProtocol {
    typealias Model = CurrencyItemData

    var executionQueue: OperationQueue {
        return currenciesDataProvider.executionQueue
    }

    func addObserver(_ observer: AnyObject, deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([CurrencyItemChange]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions) {
        synchronizationQueue.async {
            self.cacheObservers = self.cacheObservers.filter { $0.observer != nil }

            let cacheOperation = ClosureOperation<CurrencyItemData?> {
                return self.settingsManager.value(of: CurrencyItemData.self, for: self.settingsKey)
            }

            cacheOperation.completionBlock = {
                guard let result = cacheOperation.result else {
                    dispatchInQueueWhenPossible(queue) {
                        failureBlock(DataProviderError.dependencyCancelled)
                    }

                    return
                }

                switch result {
                case .success(let optionalCurrencyItem):
                    self.synchronizationQueue.async {
                        let cacheObserver = DataProviderObserver(observer: observer,
                                                                 queue: queue,
                                                                 updateBlock: updateBlock,
                                                                 failureBlock: failureBlock,
                                                                 options: options)
                        self.cacheObservers.append(cacheObserver)

                        self.updateTrigger.receive(event: .addObserver(observer))

                        if let currencyItem = optionalCurrencyItem {
                            dispatchInQueueWhenPossible(queue) {
                                updateBlock([DataProviderChange.insert(newItem: currencyItem)])
                            }
                        }
                    }
                case .failure(let error):
                    dispatchInQueueWhenPossible(queue) {
                        failureBlock(error)
                    }
                }
            }

            self.synchronizeOperation(cacheOperation)

            self.executionQueue.addOperations([cacheOperation], waitUntilFinished: false)
        }
    }

    func fetch(with completionBlock: ((Result<CurrencyItemData?, Error>?) -> Void)?)
        -> BaseOperation<CurrencyItemData?> {
        if let currencyItem = self.settingsManager.value(of: CurrencyItemData.self, for: self.settingsKey) {
            let operation = BaseOperation<CurrencyItemData?>()
            operation.result = .success(currencyItem)

            operation.completionBlock = {
                completionBlock?(operation.result)
            }

            executionQueue.addOperation(operation)
            return operation
        }

        let currenciesOperation = currenciesDataProvider.fetch(with: nil)

        let processingOperation = ClosureOperation<CurrencyItemData?> {
            guard let result = currenciesOperation.result else {
                throw BaseOperationError.parentOperationCancelled
            }

            switch result {
            case .success(let currencies):
                if let currencies = currencies,
                    let currency = self.firstMatchingLocale(from: currencies.sortedItems()) {
                    return currency
                } else {
                    return self.defaultCurrencyItem
                }
            case .failure(let error):
                throw error
            }
        }

        processingOperation.addDependency(currenciesOperation)

        processingOperation.completionBlock = {
            completionBlock?(processingOperation.result)
        }

        executionQueue.addOperation(processingOperation)

        updateTrigger.receive(event: .fetchById(settingsKey))

        return processingOperation
    }

    func removeObserver(_ observer: AnyObject) {
        synchronizationQueue.async {
            self.cacheObservers = self.cacheObservers.filter { $0.observer !== observer && $0.observer != nil}

            self.updateTrigger.receive(event: .removeObserver(observer))
        }
    }

    func refresh() {
        currenciesDataProvider.refresh()
    }

    func replaceModel(with newModel: Model) {
        synchronizationQueue.async {
            self.scheduleReplaceModel(with: newModel)
        }
    }
}

extension SelectedCurrencyDataProvider: DataProviderTriggerDelegate {
    func didTrigger() {
        currenciesDataProvider.refresh()
    }
}
