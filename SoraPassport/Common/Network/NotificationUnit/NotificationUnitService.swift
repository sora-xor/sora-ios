/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto

enum NotificationServiceType: String {
    case register
    case exchangeTokens
    case enablePermission
}

final class NotificationUnitService: BaseService {
    private(set) var unit: ServiceUnit
    private(set) var requestSigner: DARequestSigner

    private(set) lazy var operationFactory = NotificationUnitOperationFactory()

    init(unit: ServiceUnit, requestSigner: DARequestSigner) {
        self.unit = unit
        self.requestSigner = requestSigner
    }
}

extension NotificationUnitService: NotificationUnitServiceProtocol {
    func registerUser(with info: NotificationUserInfo,
                      runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping NotificationRegisterCompletionBlock) throws -> Operation {

        guard let service = unit.service(for: NotificationServiceType.register.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let networkOperation = operationFactory.userRegistrationOperation(service.serviceEndpoint,
                                                                          info: info)
        networkOperation.requestModifier = requestSigner

        networkOperation.completionBlock = {
            queue.async {
                completionBlock(networkOperation.result)
            }
        }

        execute(operations: [networkOperation])

        return networkOperation
    }

    func exchangeTokens(with info: TokenExchangeInfo,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NotificationTokenExchangeCompletionBlock) throws -> Operation {

        guard let service = unit.service(for: NotificationServiceType.exchangeTokens.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let networkOperation = operationFactory.tokenExchangeOperation(service.serviceEndpoint,
                                                                       info: info)
        networkOperation.requestModifier = requestSigner

        networkOperation.completionBlock = {
            queue.async {
                completionBlock(networkOperation.result)
            }
        }

        execute(operations: [networkOperation])

        return networkOperation
    }

    func enablePermission(for decentralizedIds: [String],
                          runCompletionIn queue: DispatchQueue,
                          completionBlock: @escaping NotificationPermissionOnCompletionBlock) throws -> Operation {

        guard let service = unit.service(for: NotificationServiceType.enablePermission.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let networkOperation = operationFactory.permissionEnableOperation(service.serviceEndpoint,
                                                                          decentralizedIds: decentralizedIds)
        networkOperation.requestModifier = requestSigner

        networkOperation.completionBlock = {
            queue.async {
                completionBlock(networkOperation.result)
            }
        }

        execute(operations: [networkOperation])

        return networkOperation
    }
}
