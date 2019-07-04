/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import RobinHood

protocol ProjectDetailsDataProviderFactoryProtocol {
    func createDetailsDataProvider(for projectId: String) -> SingleValueProvider<ProjectDetailsData, CDSingleValue>?
}

final class ProjectDetailsDataProviderFactory {
    private struct Constants {
        static let domain = "co.jp.sora.project.details"
    }

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
    func createDetailsDataProvider(for projectId: String) -> SingleValueProvider<ProjectDetailsData, CDSingleValue>? {
        guard let service = projectUnit.service(for: ProjectServiceType.projectDetails.rawValue) else {
            return nil
        }

        let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = coreDataCacheFacade
            .createCoreDataCache(domain: Constants.domain)

        let fetchDetailsBlock: () -> BaseOperation<ProjectDetailsData> = {
            let operation = self.projectUnitOperationFactory
                .fetchProjectDetailsOperation(service.serviceEndpoint, projectId: projectId)

            operation.requestModifier = self.requestSigner

            return operation
        }

        let source = AnySingleValueProviderSource(base: self, fetch: fetchDetailsBlock)

        return SingleValueProvider(targetIdentifier: projectId,
                                   source: source,
                                   cache: cache,
                                   updateTrigger: DataProviderEventTrigger.onAll)
    }
}
