/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import RobinHood

final class InformationDataProviderFacade: InformationDataProviderFacadeProtocol {
    static let announcementIdentifier = "co.jp.sora.information.announcement"
    static let helpIdentifier = "co.jp.sora.information.help"
    static let currencyIdentifier = "co.jp.sora.information.currency"
    static let countryIdentifier = "co.jp.sora.information.country"
    static let reputationDetailsIdentifier = "co.jp.sora.information.reputation.details"

    static let shared = InformationDataProviderFacade()

    lazy var config: ApplicationConfigProtocol = ApplicationConfig.shared
    lazy var requestSigner: DARequestSigner = DARequestSigner.createDefault(with: Logger.shared)!
    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    lazy var projectOperationFactory: ProjectInformationOperationFactoryProtocol = ProjectOperationFactory()

    lazy private(set) var announcementDataProvider: SingleValueProvider<AnnouncementData> = {
            let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                self.coreDataCacheFacade.createCoreDataCache()

            let source = AnySingleValueProviderSource(fetch: self.fetchAnnouncement)

            return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.announcementIdentifier,
                                       source: source,
                                       repository: AnyDataProviderRepository(cache),
                                       updateTrigger: DataProviderEventTrigger.onAddObserver,
                                       executionQueue: self.executionQueue)
    }()

    lazy private(set) var helpDataProvider: SingleValueProvider<HelpData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            self.coreDataCacheFacade.createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchHelp)

        return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.helpIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var currencyDataProvider: SingleValueProvider<CurrencyData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchCurrency)

        return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.currencyIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var countryDataProvider: SingleValueProvider<CountryData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchCountry)

        return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.countryIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var reputationDetailsProvider: SingleValueProvider<ReputationDetailsData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
        .createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchReputationDetails)

        return SingleValueProvider(targetIdentifier: InformationDataProviderFacade.reputationDetailsIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache))

    }()

    let executionQueue: OperationQueue

    init() {
        self.executionQueue = OperationQueue()
    }

    private func fetchAnnouncement() -> BaseOperation<AnnouncementData?> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.announcement.rawValue) else {
            let operation = BaseOperation<AnnouncementData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchAnnouncementOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchHelp() -> BaseOperation<HelpData?> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.help.rawValue) else {
            let operation = BaseOperation<HelpData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchHelpOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchCurrency() -> BaseOperation<CurrencyData?> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.currency.rawValue) else {
            let operation = BaseOperation<CurrencyData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchCurrencyOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchCountry() -> BaseOperation<CountryData?> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.country.rawValue) else {
            let operation = BaseOperation<CountryData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchCountryOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchReputationDetails() -> BaseOperation<ReputationDetailsData?> {
        guard let service = self.config.defaultProjectUnit
            .service(for: ProjectServiceType.reputationDetails.rawValue) else {
            let operation = BaseOperation<ReputationDetailsData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchReputationDetailsOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }
}
