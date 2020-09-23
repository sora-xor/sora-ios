/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

typealias WithdrawProofResultCompletionBlock = (Result<WithdrawProofData?, Error>?) -> Void

protocol SoranetUnitServiceProtocol {
    func fetchWithdrawProof(for info: WithdrawProofInfo,
                            runCompletionIn queue: DispatchQueue,
                            completionBlock: @escaping WithdrawProofResultCompletionBlock) throws -> Operation
}
