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
import IrohaCrypto

protocol GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> BaseOperation<[PhishingItem]>
}

class GitHubOperationFactory: GitHubOperationFactoryProtocol {
    func fetchPhishingListOperation(_ url: URL) -> BaseOperation<[PhishingItem]> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[PhishingItem]> { data in
            guard let json =
                    try JSONSerialization.jsonObject(with: data,
                                                     options: [.mutableContainers]) as? [String: AnyObject]
            else {
                return []
            }

            var phishingItems: [PhishingItem] = []

            let addressFactory = SS58AddressFactory()
            for (key, value) in json {
                if let addresses = value as? [String] {
                    for address in addresses {
                        do {
                            let typeRawValue = try addressFactory.type(fromAddress: address)

                            let addressType = SNAddressType(typeRawValue.uint16Value)

                            let accountId = try addressFactory.accountId(fromAddress: address,
                                                                         type: addressType)

                            let item = PhishingItem(source: key,
                                                    publicKey: accountId.toHex())
                            phishingItems.append(item)
                        }
                    }
                }
            }
            return phishingItems
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
