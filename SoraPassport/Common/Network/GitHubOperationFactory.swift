// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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

                            let addressType = SNAddressType(typeRawValue.uint8Value)

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
