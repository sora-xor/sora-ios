/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension BaseOperation {
    func extractResultData(throwing noResultError: Error) throws -> ResultType {
        if let result = try extractResultData() {
            return result
        } else {
            throw noResultError
        }
    }

    func extractResultData() throws -> ResultType? {
        guard let result = self.result else {
            return nil
        }

        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
