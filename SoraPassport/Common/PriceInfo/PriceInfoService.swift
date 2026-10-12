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
