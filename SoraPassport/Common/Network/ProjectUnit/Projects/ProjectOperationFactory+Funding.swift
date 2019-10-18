/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension ProjectOperationFactory: ProjectFundingOperationFactoryProtocol {
    func fetchProjectsOperation(_ urlTemplate: String, pagination: Pagination) -> NetworkOperation<[ProjectData]> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildURL(with: pagination)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[ProjectData]> { (data) in
            let resultData = try JSONDecoder().decode(ResultData<[ProjectData]>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            guard let projects = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return projects
        }

        return NetworkOperation<[ProjectData]>(requestFactory: requestFactory,
                                           resultFactory: resultFactory)
    }

    func fetchProjectDetailsOperation(_ urlTemplate: String, projectId: String)
        -> NetworkOperation<ProjectDetailsData> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(projectId)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<ProjectDetailsData> { (data) in
            let resultData = try JSONDecoder().decode(ResultData<ProjectDetailsData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let projectDetailsError = ProjectDetailsDataError.error(from: resultData.status) {
                    throw projectDetailsError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            guard let projectDetails = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return projectDetails
        }

        return NetworkOperation<ProjectDetailsData>(requestFactory: requestFactory,
                                                    resultFactory: resultFactory)
    }

    func toggleFavoriteOperation(_ urlTemplate: String, projectId: String) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(projectId)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.put.rawValue
            request.addValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = ProjectFavoriteToggleDataError.error(from: resultData.status) {
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

    func voteOperation(_ urlTemplate: String, vote: ProjectVote) -> NetworkOperation<Bool> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildURL(with: vote)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.post.rawValue
            request.addValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(ResultData<Bool>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = VoteDataError.error(from: resultData.status) {
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

    func fetchVotesOperation(_ urlTemplate: String) -> NetworkOperation<VotesData> {
        let requestFactory = BlockNetworkRequestFactory {
            guard let serviceUrl = URL(string: urlTemplate) else {
                throw NetworkBaseError.invalidUrl
            }

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<VotesData> { data in
            let resultData = try JSONDecoder().decode(MultifieldResultData<VotesData>.self, from: data)

            guard resultData.status.isSuccess else {
                if let resultError = UserDataError.error(from: resultData.status) {
                    throw resultError
                } else {
                    throw ResultStatusError(statusData: resultData.status)
                }
            }

            return resultData.result
        }

        return NetworkOperation<VotesData>(requestFactory: requestFactory,
                                           resultFactory: resultFactory)
    }

    func fetchVotesHistory(_ urlTemplate: String, with info: Pagination) -> NetworkOperation<[VotesHistoryEventData]> {
        let requestFactory = BlockNetworkRequestFactory {
            let serviceUrl = try EndpointBuilder(urlTemplate: urlTemplate).buildURL(with: info)

            var request = URLRequest(url: serviceUrl)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[VotesHistoryEventData]> { data in
            let resultData = try JSONDecoder().decode(ResultData<[VotesHistoryEventData]>.self, from: data)

            guard resultData.status.isSuccess else {
                throw ResultStatusError(statusData: resultData.status)
            }

            guard let votesHistoryEvents = resultData.result else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            return votesHistoryEvents
        }

        return NetworkOperation<[VotesHistoryEventData]>(requestFactory: requestFactory,
                                                         resultFactory: resultFactory)
    }
}
