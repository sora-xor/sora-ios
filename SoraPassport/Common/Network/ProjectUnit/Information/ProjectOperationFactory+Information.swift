/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

extension ProjectOperationFactory: ProjectInformationOperationFactoryProtocol {
    func fetchAnnouncement(_ urlTemplate: String) -> NetworkOperation<AnnouncementData?> {
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

    func fetchHelp(_ urlTemplate: String) -> NetworkOperation<HelpData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<HelpData> { data in
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

        return NetworkOperation<HelpData>(requestFactory: requestFactory,
                                          resultFactory: resultFactory)
    }

    func fetchCurrency(_ urlTemplate: String) -> NetworkOperation<CurrencyData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<CurrencyData> { data in
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

        return NetworkOperation<CurrencyData>(requestFactory: requestFactory,
                                              resultFactory: resultFactory)
    }
}
