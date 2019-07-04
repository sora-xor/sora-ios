/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension ProjectUnitService {
    func fetchAnnouncement(runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkAnnouncementCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.announcement.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchAnnouncement(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchHelp(runCompletionIn queue: DispatchQueue,
                   completionBlock: @escaping NetworkHelpCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.help.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchHelp(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchCurrency(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping NetworkCurrencyCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.currency.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchCurrency(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }
}
