import Foundation
import SoraCrypto
import RobinHood

protocol ProjectDetailsDataProviderFactoryProtocol {
    func createDetailsDataProvider(for projectId: String) -> SingleValueProvider<ProjectDetailsData>?
    func createReferendumDataProvider(for referendumId: String) -> SingleValueProvider<ReferendumData>?
}

final class ProjectDetailsDataProviderFactory {
    private(set) var requestSigner: DARequestSigner
    private(set) var projectUnit: ServiceUnit

    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    lazy private var projectUnitOperationFactory = ProjectOperationFactory()

    init(requestSigner: DARequestSigner, projectUnit: ServiceUnit) {
        self.requestSigner = requestSigner
        self.projectUnit = projectUnit
    }
}

extension ProjectDetailsDataProviderFactory: ProjectDetailsDataProviderFactoryProtocol {
    func createDetailsDataProvider(for projectId: String) -> SingleValueProvider<ProjectDetailsData>? {
        guard let service = projectUnit.service(for: ProjectServiceType.projectDetails.rawValue) else {
            return nil
        }

        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = coreDataCacheFacade
            .createCoreDataCache()

        let fetchDetailsBlock: () -> CompoundOperationWrapper<ProjectDetailsData?> = {
            let operation = self.projectUnitOperationFactory
                .fetchProjectDetailsOperation(service.serviceEndpoint, projectId: projectId)

            operation.requestModifier = self.requestSigner

            return CompoundOperationWrapper(targetOperation: operation)
        }

        let source = AnySingleValueProviderSource(fetch: fetchDetailsBlock)

        return SingleValueProvider(targetIdentifier: projectId,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver)
    }

    func createReferendumDataProvider(for referendumId: String) -> SingleValueProvider<ReferendumData>? {
        guard let service = projectUnit.service(for: ProjectServiceType.referendumDetails.rawValue) else {
            return nil
        }

        let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = coreDataCacheFacade
            .createCoreDataCache()

        let fetchDetailsBlock: () -> CompoundOperationWrapper<ReferendumData?> = {
            let operation = self.projectUnitOperationFactory
                .fetchReferendumDetailsOperation(service.serviceEndpoint, referendumId: referendumId)

            operation.requestModifier = self.requestSigner

            return CompoundOperationWrapper(targetOperation: operation)
        }

        let source = AnySingleValueProviderSource(fetch: fetchDetailsBlock)

        return SingleValueProvider(targetIdentifier: referendumId,
                                   source: source,
                                   repository: AnyDataProviderRepository(cache),
                                   updateTrigger: DataProviderEventTrigger.onAddObserver)
    }
}
