/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils
import RobinHood

extension AnyDataProviderRepository where AnyDataProviderRepository.Model == ChainStorageItem {
    func queryStorageByKey<T: ScaleDecodable>(_ identifier: String) -> CompoundOperationWrapper<T?> {
        let fetchOperation = self.fetchOperation(by: identifier,
                                                 options: RepositoryFetchOptions())

        let decoderOperation = ScaleDecoderOperation<T>()
        decoderOperation.configurationBlock = {
            do {
                decoderOperation.data = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?
                    .data
            } catch {
                decoderOperation.result = .failure(error)
            }
        }

        decoderOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: decoderOperation,
                                        dependencies: [fetchOperation])
    }
}
