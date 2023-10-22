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

protocol CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[PriceData]>
}

final class CoingeckoOperationFactory {
    private func buildURLForAssets(
        _ tokenIds: [String],
        method: String,
        currencies: [String] = ["usd"]
    ) -> URL? {
        guard var components = URLComponents(
            url: CoingeckoAPI.baseURL.appendingPathComponent(method),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        let tokenIDParam = tokenIds.joined(separator: ",")
        let currencyParam = currencies.joined(separator: ",")

        components.queryItems = [
            URLQueryItem(name: "ids", value: tokenIDParam),
            URLQueryItem(name: "vs_currencies", value: currencyParam),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]

        return components.url
    }
}

extension CoingeckoOperationFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(for tokenIds: [String]) -> BaseOperation<[PriceData]> {
        guard let url = buildURLForAssets(tokenIds, method: CoingeckoAPI.price) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<[PriceData]> { data in
            let priceData = try JSONDecoder().decode(
                [String: CoingeckoPriceData].self,
                from: data
            )

            return tokenIds.compactMap { assetId in
                guard let priceData = priceData[assetId] else {
                    return nil
                }

                return PriceData(
                    price: priceData.usdPrice.stringWithPointSeparator,
                    usdDayChange: priceData.usdDayChange
                )
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
