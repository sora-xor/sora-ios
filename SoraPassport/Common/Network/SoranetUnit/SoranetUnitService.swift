/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum SoranetServiceType: String {
    case withdrawProof
}

final class SoranetUnitService: BaseService {
    let unit: ServiceUnit
    let operationFactory: SoranetUnitOperationFactoryProtocol

    init(unit: ServiceUnit, operationFactory: SoranetUnitOperationFactoryProtocol) {
        self.unit = unit
        self.operationFactory = operationFactory
    }
}

extension SoranetUnitService: SoranetUnitServiceProtocol {
    func fetchWithdrawProof(for info: WithdrawProofInfo,
                            runCompletionIn queue: DispatchQueue,
                            completionBlock: @escaping WithdrawProofResultCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: SoranetServiceType.withdrawProof.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.withdrawProofOperation(service.serviceEndpoint, info: info)

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

}
