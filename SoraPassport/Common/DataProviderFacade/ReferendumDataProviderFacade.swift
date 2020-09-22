/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import RobinHood

final class ReferendumDataProviderFacade: ReferendumDataProviderFacadeProtocol {
    static let openDomain = "co.jp.sora.referendums.open"
    static let votedDomain = "co.jp.sora.referendums.voted"
    static let finishedDomain = "co.jp.sora.referendums.finished"

    static let shared: ReferendumDataProviderFacadeProtocol = ReferendumDataProviderFacade()

    lazy var config: ApplicationConfigProtocol = ApplicationConfig.shared
    lazy var requestSigner: DARequestSigner = DARequestSigner.createDefault(with: Logger.shared)!
    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    let executionQueue: OperationQueue
    private let serialCacheQueue: DispatchQueue

    lazy private(set) var openReferendumsProvider: DataProvider<ReferendumData> = {
        let source = AnyDataProviderSource(fetchByPage: self.fetchOpenReferendums,
                                           fetchById: self.fetchReferendumByIdOperation)

        return createReferendumsProvider(with: source, domain: Self.openDomain)
    }()

    lazy private(set) var votedReferendumsProvider: DataProvider<ReferendumData> = {
        let source = AnyDataProviderSource(fetchByPage: self.fetchVotedReferendums,
                                           fetchById: self.fetchReferendumByIdOperation)

        return createReferendumsProvider(with: source, domain: Self.votedDomain)
    }()

    lazy private(set) var finishedReferendumsProvider: DataProvider<ReferendumData> = {
        let source = AnyDataProviderSource(fetchByPage: self.fetchFinishedReferendums,
                                           fetchById: self.fetchReferendumByIdOperation)

        return createReferendumsProvider(with: source, domain: Self.finishedDomain)
    }()

    init() {
        executionQueue = OperationQueue()
        serialCacheQueue = DispatchQueue(label: "co.jp.sora.referendum.dataprovider.facade")
    }

    private func createReferendumsProvider(with source: AnyDataProviderSource<ReferendumData>,
                                           domain: String,
                                           updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onNone)
        -> DataProvider<ReferendumData> {

            let filter = NSPredicate(format: "%K == %@", #keyPath(CDReferendum.domain), domain)
            let mapper = ReferendumDataMapper(domain: domain)

        let cache: CoreDataRepository<ReferendumData, CDReferendum> = coreDataCacheFacade
            .createCoreDataCache(filter: filter, mapper: AnyCoreDataMapper(mapper))

        return DataProvider(source: source,
                            repository: AnyDataProviderRepository(cache),
                            updateTrigger: updateTrigger,
                            executionQueue: executionQueue,
                            serialSyncQueue: serialCacheQueue)
    }

    private func fetchOpenReferendums(_ page: UInt) -> CompoundOperationWrapper<[ReferendumData]> {
        guard let service = config.defaultProjectUnit
            .service(for: ProjectServiceType.referendumsOpen.rawValue) else {
            let operation = BaseOperation<[ReferendumData]>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        return fetchReferendumsOperation(service.serviceEndpoint)
    }

    private func fetchVotedReferendums(_ page: UInt) -> CompoundOperationWrapper<[ReferendumData]> {
        guard let service = config.defaultProjectUnit
            .service(for: ProjectServiceType.referendumsVoted.rawValue) else {
            let operation = BaseOperation<[ReferendumData]>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        return fetchReferendumsOperation(service.serviceEndpoint)
    }

    private func fetchFinishedReferendums(_ page: UInt) -> CompoundOperationWrapper<[ReferendumData]> {
        guard let service = config.defaultProjectUnit
            .service(for: ProjectServiceType.referendumsFinished.rawValue) else {
            let operation = BaseOperation<[ReferendumData]>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        return fetchReferendumsOperation(service.serviceEndpoint)
    }

    private func fetchReferendumsOperation(_ endpoint: String)
        -> CompoundOperationWrapper<[ReferendumData]> {
        let operation = ProjectOperationFactory().fetchReferendumsOperation(endpoint)
        operation.requestModifier = requestSigner

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func fetchReferendumByIdOperation(_ identifier: String) -> CompoundOperationWrapper<ReferendumData?> {
        let operation = BaseOperation<ReferendumData?>()
        operation.result = .success(nil)
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
