/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import RobinHood

typealias NetworkDecentralizedDocumentFetchBlock = (OperationResult<DecentralizedDocumentObject>?) -> Void
typealias NetworkDecentralizedDocumentCreateBlock = (OperationResult<Bool>?) -> Void

protocol DecentralizedResolverServiceProtocol {
    @discardableResult
    func fetchDecentralizedDocument(decentralizedId: String,
                                    runIn completionQueue: DispatchQueue,
                                    with completionBlock: @escaping NetworkDecentralizedDocumentFetchBlock) -> Operation

    @discardableResult
    func create(document: DecentralizedDocumentObject,
                runIn completionQueue: DispatchQueue,
                with completionBlock: @escaping NetworkDecentralizedDocumentCreateBlock) -> Operation
}

final class DecentralizedResolverService: BaseService, DecentralizedResolverServiceProtocol {
    private var operationFactory: DecentralizedResolverOperationFactoryProtocol

    init(url: URL) {
        operationFactory = DecentralizedResolverOperationFactory(url: url)
    }

    @discardableResult
    func fetchDecentralizedDocument(decentralizedId: String,
                                    runIn completionQueue: DispatchQueue,
                                    with completionBlock: @escaping NetworkDecentralizedDocumentFetchBlock)
        -> Operation {

        let operation = operationFactory.createDecentralizedDocumentFetchOperation(decentralizedId: decentralizedId)

        operation.completionBlock = {
            completionQueue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

    @discardableResult
    func create(document: DecentralizedDocumentObject,
                runIn completionQueue: DispatchQueue,
                with completionBlock: @escaping NetworkDecentralizedDocumentCreateBlock) -> Operation {

        let operation = operationFactory.createDecentralizedDocumentOperation { return document }

        operation.completionBlock = {
            completionQueue.async {
                completionBlock(operation.result)
            }
        }

        execute(operations: [operation])

        return operation
    }

}
