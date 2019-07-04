/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import RobinHood

final class InformationDataProviderFacade: InformationDataProviderFacadeProtocol {
    static let cacheDomain = "co.jp.sora.information"
    static let announcementIdentifier = "co.jp.sora.information.announcement"
    static let helpIdentifier = "co.jp.sora.information.help"
    static let currencyIdentifier = "co.jp.sora.information.currency"

    static let shared = InformationDataProviderFacade()

    lazy var config: ApplicationConfigProtocol = ApplicationConfig.shared
    lazy var requestSigner: DARequestSigner = DARequestSigner.createDefault(with: Logger.shared)!
    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    lazy var projectOperationFactory: ProjectInformationOperationFactoryProtocol = ProjectOperationFactory()

    lazy private(set) var announcementDataProvider: SingleValueProvider<AnnouncementData?, CDSingleValue> = {
            let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: InformationDataProviderFacade.cacheDomain)

            let source = AnySingleValueProviderSource(base: self, fetch: self.fetchAnnouncement)

            return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.announcementIdentifier,
                                       source: source,
                                       cache: cache,
                                       updateTrigger: DataProviderEventTrigger.onAddObserver,
                                       executionQueue: self.executionQueue)
    }()

    lazy private(set) var helpDataProvider: SingleValueProvider<HelpData, CDSingleValue> = {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: InformationDataProviderFacade.cacheDomain)

        let source = AnySingleValueProviderSource(base: self, fetch: self.fetchHelp)

        return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.helpIdentifier,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var currencyDataProvider: SingleValueProvider<CurrencyData, CDSingleValue> = {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: InformationDataProviderFacade.cacheDomain)

        let source = AnySingleValueProviderSource(base: self, fetch: self.fetchCurrency)

        return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.currencyIdentifier,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    let executionQueue: OperationQueue

    init() {
        self.executionQueue = OperationQueue()
    }

    private func fetchAnnouncement() -> BaseOperation<AnnouncementData?> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.announcement.rawValue) else {
            let operation = BaseOperation<AnnouncementData?>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchAnnouncement(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchHelp() -> BaseOperation<HelpData> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.help.rawValue) else {
            let operation = BaseOperation<HelpData>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchHelp(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchCurrency() -> BaseOperation<CurrencyData> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.currency.rawValue) else {
            let operation = BaseOperation<CurrencyData>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchCurrency(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }
}
