import Foundation
import SoraCrypto
import RobinHood

final class CustomerDataProviderFacade: CustomerDataProviderFacadeProtocol {
    static let votesIdentifier = "co.jp.sora.user.votes"
    static let userIdentifier = "co.jp.sora.user.data"
    static let friendsIdentifier = "co.jp.sora.user.friends"
    static let reputationIdentifier = "co.jp.sora.user.reputation"

    static let shared: CustomerDataProviderFacade = CustomerDataProviderFacade()

    lazy var config: ApplicationConfigProtocol = ApplicationConfig.shared
    lazy var requestSigner: DARequestSigner = DARequestSigner.createDefault(with: Logger.shared)!
    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    lazy var projectOperationFactory: ProjectAccountOperationFactoryProtocol &
        ProjectFundingOperationFactoryProtocol = ProjectOperationFactory()

    let executionQueue: OperationQueue

    lazy private(set) var votesProvider: SingleValueProvider<VotesData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            self.coreDataCacheFacade.createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchVotesOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.votesIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var userProvider: SingleValueProvider<UserData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            self.coreDataCacheFacade.createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchUserOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.userIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var friendsDataProvider: SingleValueProvider<ActivatedInvitationsData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            self.coreDataCacheFacade.createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchFriendsOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.friendsIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    lazy private(set) var reputationDataProvider: SingleValueProvider<ReputationData> = {
        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            self.coreDataCacheFacade.createCoreDataCache()

        let source = AnySingleValueProviderSource(fetch: self.fetchReputationOperation)

        return SingleValueProvider(targetIdentifier: CustomerDataProviderFacade.reputationIdentifier,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver,
                                   executionQueue: self.executionQueue)
    }()

    init() {
        executionQueue = OperationQueue()
    }

    private func fetchVotesOperation() -> CompoundOperationWrapper<VotesData?> {
        guard let service = self.config.defaultProjectUnit.service(for: ProjectServiceType.votesCount.rawValue) else {
            let operation = BaseOperation<VotesData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let operation = projectOperationFactory.fetchVotesOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func fetchUserOperation() -> CompoundOperationWrapper<UserData?> {
        let projectUnit = self.config.defaultProjectUnit
        guard let service = projectUnit.service(for: ProjectServiceType.customer.rawValue) else {
            let operation = BaseOperation<UserData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let operation = projectOperationFactory.fetchCustomerOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func fetchFriendsOperation() -> CompoundOperationWrapper<ActivatedInvitationsData?> {
        let projectUnit = self.config.defaultProjectUnit
        guard let service = projectUnit.service(for: ProjectServiceType.fetchInvited.rawValue) else {
            let operation = BaseOperation<ActivatedInvitationsData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let operation = projectOperationFactory.fetchActivatedInvitationsOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func fetchReputationOperation() -> CompoundOperationWrapper<ReputationData?> {
        let projectUnit = self.config.defaultProjectUnit
        guard let service = projectUnit.service(for: ProjectServiceType.reputation.rawValue) else {
            let operation = BaseOperation<ReputationData?>()
            operation.result = .failure(NetworkUnitError.serviceUnavailable)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let operation = projectOperationFactory.fetchReputationOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
