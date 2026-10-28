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
import IrohaCrypto
import RobinHood
import sorawallet

struct PriceInfo {
    let fiatData: [PIExactFiatData]
    let marketCapInfo: Set<MarketCapInfo>
    /// `nil` when the prices are current. Otherwise the time they date
    /// from, which the wallet shows next to its total.
    var pricesAsOf: Date? = nil
}

protocol PriceInfoServiceProtocol: AnyObject {
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo
}

actor PriceInfoService {
    static let shared = PriceInfoService()
    private let fiatService: FiatService
    private let marketCapService: MarketCapService

    init(
        fiatService: FiatService = .shared,
        marketCapService: MarketCapService = .shared
    ) {
        self.fiatService = fiatService
        self.marketCapService = marketCapService
    }
    
    private func downloadInfo(for assetIds: [String]) async -> PriceInfo {
        async let fiat = self.fiatService.getFiatSnapshot()
        async let assetInfo = self.marketCapService.getMarketCap(for: assetIds)
        
        let prices = await fiat
        return await PriceInfo(
            fiatData: prices.data,
            marketCapInfo: assetInfo,
            pricesAsOf: prices.asOf
        )
    }
}

extension PriceInfoService: PriceInfoServiceProtocol {

    /// Prices and market data for the given assets. The shared PI asset
    /// catalog behind both services does the caching (ten minutes), the
    /// single flight and the backoff after a failure, so this neither keeps
    /// a first answer for the rest of the session nor walks PI again on
    /// every call while PI is failing. Neither service caches on top of
    /// the catalog, so the prices and the 24-hour changes of one answer
    /// are from the same catalog.
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo {
        await downloadInfo(for: assetIds)
    }
}
