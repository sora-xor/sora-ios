/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension ProjectUnitService {
    func fetchAnnouncement(runCompletionIn queue: DispatchQueue,
                           completionBlock: @escaping NetworkAnnouncementCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.announcement.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchAnnouncementOperation(service.serviceEndpoint)
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

        let operation = operationFactory.fetchHelpOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchReputationDetails(runCompletionIn queue: DispatchQueue,
                                completionBlock: @escaping NetworkReputationDetailsCompletionBlock)
        throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.reputationDetails.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchReputationDetailsOperation(service.serviceEndpoint)
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

        let operation = operationFactory.fetchCurrencyOperation(service.serviceEndpoint)
        operation.requestModifier = requestSigner

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func checkSupported(version: String,
                        runCompletionIn queue: DispatchQueue,
                        completionBlock: @escaping NetworkSupportedVersionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.supportedVersion.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.checkSupportedVersionOperation(service.serviceEndpoint, version: version)

        operation.completionBlock = {
            queue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    func fetchCountry(runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping NetworkCountryCompletionBlock) throws -> Operation {
        guard let service = unit.service(for: ProjectServiceType.country.rawValue) else {
            throw NetworkUnitError.serviceUnavailable
        }

        let operation = operationFactory.fetchCountryOperation(service.serviceEndpoint)
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
