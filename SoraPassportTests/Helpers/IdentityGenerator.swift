/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
@testable import SoraPassport
import SoraCrypto
import XCTest

func createIdentity() -> DecentralizedDocumentObject {
    let identityOperation = IdentityOperationFactory.createNewIdentityOperation()

    let semaphore = DispatchSemaphore(value: 0)

    var ddo: DecentralizedDocumentObject?

    identityOperation.completionBlock = {
        defer {
            semaphore.signal()
        }

        guard let result = identityOperation.result, case .success(let document) = result else {
            return
        }

        ddo = document
    }

    OperationManager.shared.enqueue(operations: [identityOperation], in: .normal)

    _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(Constants.expectationDuration * 1000)))

    return ddo!
}
