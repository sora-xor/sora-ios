/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

typealias NotificationRegisterCompletionBlock = (OperationResult<Bool>?) -> Void
typealias NotificationTokenExchangeCompletionBlock = (OperationResult<Bool>?) -> Void
typealias NotificationPermissionOnCompletionBlock = (OperationResult<Bool>?) -> Void

protocol NotificationUnitServiceProtocol: BaseServiceProtocol {
    func registerUser(with info: NotificationUserInfo,
                      runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping NotificationRegisterCompletionBlock) throws -> Operation

    func exchangeTokens(with info: TokenExchangeInfo,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NotificationTokenExchangeCompletionBlock) throws -> Operation

    func enablePermission(for decentralizedIds: [String],
                          runCompletionIn queue: DispatchQueue,
                          completionBlock: @escaping NotificationPermissionOnCompletionBlock) throws -> Operation
}
