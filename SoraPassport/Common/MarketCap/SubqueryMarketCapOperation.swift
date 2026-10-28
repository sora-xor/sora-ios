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
    /// As many assets as the catalog walk can return
    /// (`PIIndexerClient.maximumCatalogPages` pages of 100).
    static let maximumRequestedAssetCount = 10_000
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
    private let baseUrl: URL
    private let catalog: () async throws -> [PIAsset]

    public convenience init(baseUrl: URL, assetIds: [String]) {
        // The same catalog read that serves fiat prices: opening the wallet
        // walks PI once, not once per service.
        self.init(baseUrl: baseUrl, assetIds: assetIds) {
            try await PICatalogs.assets.values()
        }
    }

    init(
        baseUrl: URL,
        assetIds: [String],
        catalog: @escaping () async throws -> [PIAsset]
    ) {
        self.assetIds = assetIds
        self.baseUrl = baseUrl
        self.catalog = catalog
        super.init()
    }

    override public func execute() async throws -> ResultType {
        // Admission must precede the catalog read: an empty, duplicate, or
        // unbounded production request must never turn into a full-catalog
        // network fetch.
        let requested = try PIMarketCapCatalogValidator
            .validatedRequestedAssetIDs(assetIds)
        // The shared catalog reads the reviewed production PI only.
        try PIIndexerClient.validateProductionEndpoint(baseUrl)
        let assets = try await catalog()
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
