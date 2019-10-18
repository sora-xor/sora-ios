/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
@testable import SoraPassport

func createTestOperation<ResultType>(url: URL, resultValue: ResultType) -> NetworkOperation<ResultType> {
    let requestFactory = BlockNetworkRequestFactory {
        return URLRequest(url: url)
    }

    let resultFactory = AnyNetworkResultFactory
    { (data: Data?, response: URLResponse?, error: Error?) -> OperationResult<ResultType> in
        if let existingError = error {
            return .error(existingError)
        } else {
            return .success(resultValue)
        }
    }

    let operation = NetworkOperation<ResultType>(requestFactory: requestFactory,
                                                 resultFactory: resultFactory)
    return operation
}
