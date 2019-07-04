/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import RobinHood

final class CustomerDataProviderFacade: CustomerDataProviderFacadeProtocol {
    static let votesIdentifier = "co.jp.sora.user.votes"
    static let userIdentifier = "co.jp.sora.user.data"
    static let friendsIdentifier = "co.jp.sora.user.friends"
    static let reputationIdentifier = "co.jp.sora.user.reputation"
    static let cacheDomain = "co.jp.sora.user"

    static let shared: CustomerDataProviderFacade = CustomerDataProviderFacade()

    lazy var config: ApplicationConfigProtocol = ApplicationConfig.shared
    lazy var requestSigner: DARequestSigner = DARequestSigner.createDefault(with: Logger.shared)!
    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    lazy var projectOperationFactory: ProjectAccountOperationFactoryProtocol &
        ProjectFundingOperationFactoryProtocol = ProjectOperationFactory()

    let executionQueue: OperationQueue

    lazy private(set) var votesProvider: SingleValueProvider<VotesData, CDSingleValue> = {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: CustomerDataProviderFacade.cacheDomain)

        let source = AnySingleValueProviderSource(base: self, fetch: self.fetchVotesOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.votesIdentifier,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var userProvider: SingleValueProvider<UserData, CDSingleValue> = {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: CustomerDataProviderFacade.cacheDomain)

        let source = AnySingleValueProviderSource(base: self, fetch: self.fetchUserOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.userIdentifier,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var friendsDataProvider: SingleValueProvider<ActivatedInvitationsData, CDSingleValue> = {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: CustomerDataProviderFacade.cacheDomain)

        let source = AnySingleValueProviderSource(base: self, fetch: self.fetchFriendsOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.friendsIdentifier,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var reputationDataProvider: SingleValueProvider<ReputationData, CDSingleValue> = {
        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = self.coreDataCacheFacade
            .createCoreDataCache(domain: CustomerDataProviderFacade.cacheDomain)

        let source = AnySingleValueProviderSource(base: self, fetch: self.fetchReputationOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.reputationIdentifier,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    init() {
        executionQueue = OperationQueue()
    }

    private func fetchVotesOperation() -> BaseOperation<VotesData> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.votesCount.rawValue) else {
            let operation = BaseOperation<VotesData>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchVotesOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchUserOperation() -> BaseOperation<UserData> {
        let projectUnit = self.config.defaultProjectUnit
        guard let service = projectUnit.service(for: ProjectServiceType.customer.rawValue) else {
            let operation = BaseOperation<UserData>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchCustomerOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchFriendsOperation() -> BaseOperation<ActivatedInvitationsData> {
        let projectUnit = self.config.defaultProjectUnit
        guard let service = projectUnit.service(for: ProjectServiceType.fetchInvited.rawValue) else {
            let operation = BaseOperation<ActivatedInvitationsData>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchActivatedInvitationsOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }

    private func fetchReputationOperation() -> BaseOperation<ReputationData> {
        let projectUnit = self.config.defaultProjectUnit
        guard let service = projectUnit.service(for: ProjectServiceType.reputation.rawValue) else {
            let operation = BaseOperation<ReputationData>()
            operation.result = .error(NetworkUnitError.serviceUnavailable)
            return operation
        }

        let operation = projectOperationFactory.fetchReputationOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return operation
    }
}
