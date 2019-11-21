/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension ProjectOperationFactory: ProjectAccountOperationFactoryProtocol {
    func registrationOperation(_ urlTemplate: String, with info: RegistrationInfo) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildURL(with: info)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = RegistrationDataError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation<Bool>(requestFactory: requestFactory,
                                      resultFactory: resultFactory)
    }

    func createUserOperation(_ urlTemplate: String,
                             with info: UserCreationInfo) -> NetworkOperation<VerificationCodeData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<VerificationCodeData> { data in
            let resultData = try JSONDecoder().decode(MultifieldResultData<VerificationCodeData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = UserCreationError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return resultData.result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchCustomerOperation(_ urlTemplate: String) -> NetworkOperation<UserData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<UserData?> { data in
            let resultData = try JSONDecoder().decode(ResultData<UserData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = UserDataError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let userData = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return userData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func updateCustomerOperation(_ urlTemplate: String, info: PersonalInfo) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpBody = try JSONEncoder().encode(info)
            request.httpMethod = HttpMethod.put.rawValue
            request.addValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { (data) in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = UserDataError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchInvitationCodeOperation(_ urlTemplate: String) -> NetworkOperation<InvitationCodeData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<InvitationCodeData> { data in
            if let resultData = try? JSONDecoder().decode(InvitationCodeData.self, from: data) {
                return resultData
            } else {
                let statusData = try JSONDecoder().decode(ResultData<InvitationCodeData>.self, from: data)
                if let resultError = InvitationCodeDataError.error(from: statusData.status) {
                    throw resultError
                } else {
                    throw NetworkBaseError.unexpectedResponseObject
                }
            }
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func applyInvitationCodeOperation(_ urlTemplate: String, code: String) -> NetworkOperation<Void> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(code)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> { data in
            let statusData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard statusData.status.isSuccess else {
                if let invitationApplyError = ApplyInvitationDataError.error(from: statusData.status) {
                    throw invitationApplyError
                } else {
                    throw ResultStatusError(statusData: statusData.status)
                }
            }
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func markAsUsedOperation(_ urlTemplate: String, invitationCode: String) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate)
                .buildParameterURL(invitationCode)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.put.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let invitationMarkError = InvitationMarkDataError.error(from: resultData.status) {
                    throw invitationMarkError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return true
        }

        return NetworkOperation<Bool>(requestFactory: requestFactory,
                                      resultFactory: resultFactory)
    }

    func checkInvitation(_ urlTemplate: String, deviceInfo: DeviceInfo) -> NetworkOperation<InvitationCheckData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.httpBody = try JSONEncoder().encode(deviceInfo)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<InvitationCheckData> { data in
            let resultData = try JSONDecoder().decode(MultifieldResultData<InvitationCheckData>.self,
                                                      from: data)

            guard resultData.status.isSuccess else {
                if let invitationCheckError = InvitationCheckDataError.error(from: resultData.status) {
                    throw invitationCheckError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return resultData.result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchActivatedInvitationsOperation(_ urlTemplate: String) -> NetworkOperation<ActivatedInvitationsData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<ActivatedInvitationsData?> { data in
            let resultData = try JSONDecoder().decode(MultifieldResultData<ActivatedInvitationsData>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            return resultData.result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchReputationOperation(_ urlTemplate: String) -> NetworkOperation<ReputationData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<ReputationData?> { (data) in
            let resultData = try JSONDecoder().decode(ResultData<ReputationData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = UserDataError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let reputation = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return reputation
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchActivityFeedOperation(_ urlTemplate: String,
                                    with page: Pagination) -> NetworkOperation<ActivityData?> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildURL(with: page)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<ActivityData?> { data in
            let resultData = try JSONDecoder().decode(MultifieldResultData<ActivityData>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            return resultData.result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func sendSmsCodeOperation(_ urlTemplate: String) -> NetworkOperation<VerificationCodeData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<VerificationCodeData> { (data) in
            let verificationData = try JSONDecoder().decode(VerificationCodeData.self, from: data)
            return verificationData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func verifySmsCodeOperation(_ urlTemplate: String, info: VerificationCodeInfo) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { (data) in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = SmsCodeVerifyDataError.error(from: resultData.status) {
                    throw resultError
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
