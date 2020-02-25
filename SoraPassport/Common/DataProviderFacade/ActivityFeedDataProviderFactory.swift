/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import RobinHood

protocol ActivityFeedDataProviderFactoryProtocol {
    func createActivityFeedDataProvider(with pageSize: Int, updateTrigger: DataProviderTriggerProtocol)
        -> SingleValueProvider<ActivityData>?
}

final class ActivityFeedDataProviderFactory {
    private struct Constants {
        static let targetIdentifier = "co.jp.sora.projects.activity.feed"
    }

    private(set) var requestSigner: DARequestSigner
    private(set) var projectUnit: ServiceUnit

    lazy private var projectUnitOperationFactory = ProjectOperationFactory()
    lazy var coreDataCacheFacade: CoreDataCacheFacadeProtocol = CoreDataCacheFacade.shared

    init(requestSigner: DARequestSigner, projectUnit: ServiceUnit) {
        self.requestSigner = requestSigner
        self.projectUnit = projectUnit
    }
}

extension ActivityFeedDataProviderFactory: ActivityFeedDataProviderFactoryProtocol {
    func createActivityFeedDataProvider(with pageSize: Int, updateTrigger: DataProviderTriggerProtocol)
        -> SingleValueProvider<ActivityData>? {
            guard let service = projectUnit.service(for: ProjectServiceType.activityFeed.rawValue) else {
                return nil
            }

            let cache: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                coreDataCacheFacade.createCoreDataCache()

            let info = Pagination(offset: 0, count: pageSize)
            let fetchActivityFeedBlock: () -> BaseOperation<ActivityData?> = {
                let activityFeedOperation = self.projectUnitOperationFactory
                    .fetchActivityFeedOperation(service.serviceEndpoint, with: info)
                activityFeedOperation.requestModifier = self.requestSigner

                return activityFeedOperation
            }

            let source = AnySingleValueProviderSource(fetch: fetchActivityFeedBlock)

            return SingleValueProvider(targetIdentifier: Constants.targetIdentifier,
                                       source: source,
                                       repository: AnyDataProviderRepository(cache),
                                       updateTrigger: updateTrigger)
    }
}
