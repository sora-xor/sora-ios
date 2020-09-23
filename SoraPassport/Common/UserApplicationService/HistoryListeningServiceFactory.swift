/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CoreData

struct HistoryListeningServiceFactory: UserApplicationServiceFactoryProtocol {
    func createServices() -> [UserApplicationServiceProtocol] {
        let transferObserver: CoreDataContextObservable<TransferOperationData, CDTransfer> =
            createObserver()
        let anyTransferObserver = AnyDataProviderRepositoryObservable(transferObserver)

        let withdrawObserver: CoreDataContextObservable<WithdrawOperationData, CDWithdraw> =
            createObserver()
        let anyWithdrawObserver = AnyDataProviderRepositoryObservable(withdrawObserver)

        let depositObserver: CoreDataContextObservable<DepositOperationData, CDDeposit> =
            createObserver()
        let anyDepositObserver = AnyDataProviderRepositoryObservable(depositObserver)

        let service = HistoryListeningService(eventCenter: EventCenter.shared,
                                              transferObserver: anyTransferObserver,
                                              withdrawObserver: anyWithdrawObserver,
                                              depositObserver: anyDepositObserver)

        return [service]
    }

    private func createObserver<T: Codable, U: NSManagedObject & CoreDataCodable>()
        -> CoreDataContextObservable<T, U> {
        let mapper = CodableCoreDataMapper<T, U>()
        let observer = CoreDataContextObservable<T, U>(
                service: UserStoreFacade.shared.databaseService,
                mapper: AnyCoreDataMapper(mapper),
                predicate: { _ in true })

        observer.start { error in
            if let error = error {
                Logger.shared.error("Can't start deposit observer: \(error)")
            }
        }

        return observer
    }
}
