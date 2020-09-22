/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class HistoryListeningService {
    let eventCenter: EventCenterProtocol
    let transferObserver: AnyDataProviderRepositoryObservable<TransferOperationData>
    let withdrawObserver: AnyDataProviderRepositoryObservable<WithdrawOperationData>
    let depositObserver: AnyDataProviderRepositoryObservable<DepositOperationData>

    init(eventCenter: EventCenterProtocol,
         transferObserver: AnyDataProviderRepositoryObservable<TransferOperationData>,
         withdrawObserver: AnyDataProviderRepositoryObservable<WithdrawOperationData>,
         depositObserver: AnyDataProviderRepositoryObservable<DepositOperationData>) {
        self.eventCenter = eventCenter
        self.transferObserver = transferObserver
        self.depositObserver = depositObserver
        self.withdrawObserver = withdrawObserver
    }
}

extension HistoryListeningService: UserApplicationServiceProtocol {
    func setup() {
        transferObserver.addObserver(self, deliverOn: .main) { [weak self] _ in
            self?.eventCenter.notify(with: WalletUpdateEvent())
        }

        withdrawObserver.addObserver(self, deliverOn: .main) { [weak self] _ in
            self?.eventCenter.notify(with: WalletUpdateEvent())
        }

        depositObserver.addObserver(self, deliverOn: .main) { [weak self] _ in
            self?.eventCenter.notify(with: WalletUpdateEvent())
        }
    }

    func throttle() {
        transferObserver.removeObserver(self)
        withdrawObserver.removeObserver(self)
        depositObserver.removeObserver(self)
    }
}
