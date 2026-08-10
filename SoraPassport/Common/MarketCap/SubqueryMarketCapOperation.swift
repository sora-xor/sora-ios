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

import sorawallet
import Foundation

enum PIMarketCapLiquidityValidator {
    static func validatedWireValue(_ quantity: PIQuantity?) throws -> String {
        guard
            let rawValue = quantity?.rawValue,
            rawValue.range(
                of: #"^(?:0|[1-9][0-9]*)$"#,
                options: .regularExpression
            ) != nil
        else {
            throw PIIndexerError.invalidQuantity
        }
        return rawValue
    }
}

enum PIMarketCapCatalogValidator {
    static let maximumRequestedAssetCount = 2_000
    static let maximumAssetIDBytes = 256

    static func validatedRequestedAssetIDs(
        _ requestedAssetIDs: [String]
    ) throws -> Set<String> {
        let requested = Set(requestedAssetIDs)
        guard
            (1 ... maximumRequestedAssetCount).contains(
                requestedAssetIDs.count
            ),
            requested.count == requestedAssetIDs.count,
            requestedAssetIDs.allSatisfy({ assetID in
                !assetID.isEmpty &&
                    assetID.utf8.count <= maximumAssetIDBytes &&
                    assetID == assetID.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) &&
                    assetID.unicodeScalars.allSatisfy({
                        !CharacterSet.controlCharacters.contains($0)
                    })
            })
        else {
            throw PIIndexerError.invalidResponse
        }
        return requested
    }

    static func requireExactRequestedCoverage(
        requestedAssetIDs: [String],
        returnedAssetIDs: [String]
    ) throws {
        let requested = try validatedRequestedAssetIDs(requestedAssetIDs)
        let returned = Set(returnedAssetIDs)
        guard
            returned.count == returnedAssetIDs.count,
            returned == requested
        else {
            throw PIIndexerError.invalidResponse
        }
    }
}

public final class SubqueryMarketCapInfoOperation<ResultType>: PIAsyncOperation<ResultType> {
    private let assetIds: [String]
    private let client: PIIndexerClient

    public init(baseUrl: URL, assetIds: [String]) {
        self.assetIds = assetIds
        client = PIIndexerClient(endpoint: baseUrl)
        super.init()
    }

    override public func execute() async throws -> ResultType {
        // Admission must precede `allAssets()`: an empty, duplicate, or
        // unbounded production request must never turn into a full-catalog
        // network fetch.
        let requested = try PIMarketCapCatalogValidator
            .validatedRequestedAssetIDs(assetIds)
        let assets = try await client.allAssets()
            .filter { requested.contains($0.id) }
        try PIMarketCapCatalogValidator.requireExactRequestedCoverage(
            requestedAssetIDs: assetIds,
            returnedAssetIDs: assets.map(\.id)
        )
        let values = try assets.map { asset in
            AssetsInfo(
                tokenId: asset.id,
                liquidity: try PIMarketCapLiquidityValidator
                    .validatedWireValue(asset.liquidity),
                hourDelta: asset.priceChangeDay.map {
                    KotlinDouble(value: $0)
                }
            )
        }
        guard let result = values as? ResultType else {
            throw PIIndexerError.invalidResponse
        }
        return result
    }
}
