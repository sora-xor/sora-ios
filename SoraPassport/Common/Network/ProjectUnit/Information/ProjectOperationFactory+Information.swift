/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension ProjectOperationFactory: ProjectInformationOperationFactoryProtocol {
    func fetchAnnouncementOperation(_ urlTemplate: String) -> NetworkOperation<AnnouncementData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<AnnouncementData?> { data in
            let resultData = try JSONDecoder().decode(ResultData<[AnnouncementData]>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            guard let announcements = resultData.result else {
                throw NetworkBaseError.unexpectedEmptyData
            }

            return announcements.first
        }

        return NetworkOperation<AnnouncementData?>(requestFactory: requestFactory,
                                                   resultFactory: resultFactory)
    }

    func fetchHelpOperation(_ urlTemplate: String) -> NetworkOperation<HelpData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<HelpData?> { data in
            let resultData = try JSONDecoder().decode(ResultData<HelpData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let informationDataError = InformationDataError.error(from: resultData.status) {
                    throw informationDataError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let helpData = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return helpData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchReputationDetailsOperation(_ urlTemplate: String) -> NetworkOperation<ReputationDetailsData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<ReputationDetailsData?> { data in
            let resultData = try JSONDecoder().decode(ResultData<ReputationDetailsData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let informationDataError = InformationDataError.error(from: resultData.status) {
                    throw informationDataError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let reputationDetailsData = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return reputationDetailsData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchCurrencyOperation(_ urlTemplate: String) -> NetworkOperation<CurrencyData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<CurrencyData?> { data in
            let resultData = try JSONDecoder().decode(ResultData<CurrencyData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let informationDataError = InformationDataError.error(from: resultData.status) {
                    throw informationDataError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let currencyData = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return currencyData
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func checkSupportedVersionOperation(_ urlTemplate: String,
                                        version: String) -> NetworkOperation<SupportedVersionData> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(version)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SupportedVersionData> { data in
            let resultData = try JSONDecoder().decode(MultifieldResultData<SupportedVersionData>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            return resultData.result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchEthConfigOperation(_ urlTemplate: String) -> NetworkOperation<EthNodeData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<EthNodeData?> { data in
            let resultData = try JSONDecoder().decode(OptionalMultifieldResultData<EthNodeData?>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            guard let result = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func fetchCountryOperation(_ urlTemplate: String) -> NetworkOperation<CountryData?> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<CountryData?> { data in
            let resultData = try JSONDecoder().decode(ResultData<CountryData>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            guard let result = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return result
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
