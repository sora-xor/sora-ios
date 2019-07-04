/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import RobinHood

typealias DocumentConfigurationBlock = () throws -> DecentralizedDocumentObject

protocol DecentralizedResolverOperationFactoryProtocol {
    func createDecentralizedDocumentFetchOperation(decentralizedId: String)
        -> NetworkOperation<DecentralizedDocumentObject>

    func createDecentralizedDocumentOperation(with documentConfigBlock: @escaping DocumentConfigurationBlock)
        -> NetworkOperation<Bool>
}

final class DecentralizedResolverOperationFactory {
    private(set) var url: URL

    init(url: URL) {
        self.url = url
    }
}

extension DecentralizedResolverOperationFactory: DecentralizedResolverOperationFactoryProtocol {
    func createDecentralizedDocumentFetchOperation(decentralizedId: String)
        -> NetworkOperation<DecentralizedDocumentObject> {
        let fetchUrl = url.appendingPathComponent(decentralizedId)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: fetchUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory { (data) -> DecentralizedDocumentObject in
            let resultData = try JSONDecoder().decode(ResultData<DecentralizedDocumentObject>.self, from: data)

            guard resultData.status.isSuccess else {
                if let serviceError = DecentralizedDocumentQueryDataError.error(from: resultData.status) {
                    throw serviceError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let decentralizedObject = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return decentralizedObject
        }

        return NetworkOperation<DecentralizedDocumentObject>(requestFactory: requestFactory,
                                                             resultFactory: resultFactory)
    }

    func createDecentralizedDocumentOperation(with documentConfigBlock: @escaping DocumentConfigurationBlock)
        -> NetworkOperation<Bool> {
        let creationUrl = url

        let requestFactory = BlockNetworkRequestFactory {
            let document = try documentConfigBlock()

            var request = URLRequest(url: creationUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(document)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory { (data) -> Bool in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let serviceError = DecentralizedDocumentCreationDataError.error(from: resultData.status) {
                    throw serviceError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation<Bool>(requestFactory: requestFactory,
                                      resultFactory: resultFactory)
    }
}
