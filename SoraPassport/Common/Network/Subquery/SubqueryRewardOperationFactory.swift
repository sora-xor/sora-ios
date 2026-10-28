// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood
import SSFUtils

protocol SubqueryRewardOperationFactoryProtocol {
    func createOperation(address: String) -> BaseOperation<SubqueryRewardOrSlashData>
}

final class SubqueryRewardOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    private func prepareQueryForAddress(_ address: String) throws -> String {
        let addressLiteral = String(decoding: try JSONEncoder().encode(address), as: UTF8.self)
        return """
        {
            historyElements(
                 orderBy: TIMESTAMP_DESC,
                 filter: {
                     address: { equalTo: \(addressLiteral)},
                     reward: { isNull: false }
                 }
             ) {
                nodes {
                    id
                    timestamp
                    address
                    blockHash
                    networkFee
                    data
                    execution
                }
             }
        }
        """
    }
}

extension SubqueryRewardOperationFactory: SubqueryRewardOperationFactoryProtocol {
    func createOperation(address: String) -> BaseOperation<SubqueryRewardOrSlashData> {
        let requestFactory = BlockNetworkRequestFactory {
            let queryString = try self.prepareQueryForAddress(address)
            var request = URLRequest(url: self.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryRewardOrSlashData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryRewardOrSlashData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
