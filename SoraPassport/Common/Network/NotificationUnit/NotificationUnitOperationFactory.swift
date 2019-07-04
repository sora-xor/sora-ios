/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class NotificationUnitOperationFactory: NotificationUnitOperationFactoryProtocol {
    func userRegistrationOperation(_ urlTemplate: String, info: NotificationUserInfo) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let registrationError = NotificationRegisterDataError.error(from: resultData.status) {
                    throw registrationError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func tokenExchangeOperation(_ urlTemplate: String, info: TokenExchangeInfo) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.put.rawValue
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let tokenExchangeError = NotificationTokenExchangeDataError.error(from: resultData.status) {
                    throw tokenExchangeError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func permissionEnableOperation(_ urlTemplate: String, decentralizedIds: [String]) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.put.rawValue
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.httpBody = try JSONEncoder().encode(decentralizedIds)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let permissionError = NotificationEnablePermissionsDataError.error(from: resultData.status) {
                    throw permissionError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
