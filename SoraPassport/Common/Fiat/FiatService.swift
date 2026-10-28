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

/// Native exact PI price model. This deliberately does not expose a KMM
/// `KotlinDouble`; the decimal wire value stays intact until a UI formatter
/// requests `PIQuantity.decimalValue`.
struct PIExactFiatData: Equatable, Sendable {
    let id: String
    let priceUsd: PIQuantity?
}

extension PIAsset {
    /// The asset's price as the screens use it. PI publishes a price of
    /// exactly `0` for an asset it could not price (on 11 October 2026 that
    /// included bridged ETH, which has liquidity and daily volume). That is
    /// "no price", not "worth nothing": the holding gets no fiat text and
    /// is left out of totals, like an asset PI has no price field for.
    var fiatData: PIExactFiatData {
        PIExactFiatData(
            id: id,
            priceUsd: priceUSD.flatMap { $0.isZero ? nil : $0 }
        )
    }
}

protocol FiatServiceObserverProtocol: AnyObject {
    func processFiat(data: [PIExactFiatData])
}

protocol FiatServiceProtocol: Actor {
    func getFiat() async -> [PIExactFiatData]
}

struct FiatServiceObserver {
    weak var observer: FiatServiceObserverProtocol?
}

/// Prices as a screen may show them.
struct FiatSnapshot {
    /// Empty when no price is known.
    let data: [PIExactFiatData]
    /// `nil` when the prices are current. Otherwise the time they date
    /// from: PI could not be read since.
    let asOf: Date?
}

actor FiatService: FiatServiceProtocol {
    static let shared = FiatService()

    private let catalog: () async throws -> PICatalogSnapshot<PIAsset>

    /// Prices come from the shared asset catalog, which also feeds market
    /// data: one walk of PI serves every screen, a failed walk is not
    /// repeated before its backoff has passed, and the last good catalog is
    /// shown meanwhile.
    init(
        catalog: @escaping () async throws -> PICatalogSnapshot<PIAsset> = {
            try await PICatalogs.assets.snapshot()
        }
    ) {
        self.catalog = catalog
    }

    init(assets: @escaping () async throws -> [PIAsset]) {
        self.init(catalog: {
            PICatalogSnapshot(values: try await assets(), asOf: nil)
        })
    }

    /// Empty when no price is known. Callers must show that as "price
    /// unavailable", never as a value of zero. An unavailable price never
    /// affects balances or authorizes a transaction.
    func getFiat() async -> [PIExactFiatData] {
        await getFiatSnapshot().data
    }

    func getFiatSnapshot() async -> FiatSnapshot {
        do {
            let catalog = try await catalog()
            return FiatSnapshot(
                data: catalog.values.map(\.fiatData),
                asOf: catalog.asOf
            )
        } catch {
            return FiatSnapshot(data: [], asOf: nil)
        }
    }
}
