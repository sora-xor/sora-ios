/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CoreData

final class SingleValueOperation<T: Codable & Equatable>: BaseOperation<T> {
    let provider: SingleValueProvider<T>

    init(provider: SingleValueProvider<T>) {
        self.provider = provider

        super.init()
    }

    override func main() {
         super.main()

        var optionalResultError: Error?
        var optionalResultData: T?

        let semaphore = DispatchSemaphore(value: 0)

        let updateBlock: ([DataProviderChange<T>]) -> Void = { changes in
            if let change = changes.first {
                switch change {
                case .insert(let item), .update(let item):
                    optionalResultData = item
                    semaphore.signal()
                case .delete:
                    break
                }
            }
        }

        let failureBlock: (Error) -> Void = { error in
            optionalResultError = error

            semaphore.signal()
        }

        provider.addObserver(self,
                             deliverOn: nil,
                             executing: updateBlock,
                             failing: failureBlock,
                             options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))
        provider.refresh()

        semaphore.wait()

        provider.removeObserver(self)

        if let resultError = optionalResultError {
            result = .failure(resultError)
            return
        }

        guard let resultData = optionalResultData else {
            result = .failure(NetworkBaseError.unexpectedResponseObject)
            return
        }

        result = .success(resultData)
    }
}
