/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

protocol SoranetUnitOperationFactoryProtocol: class {
    func withdrawProofOperation(_ urlTemplate: String, info: WithdrawProofInfo) -> NetworkOperation<WithdrawProofData?>
}
