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
