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

protocol SwapMarketSourcerProtocol {
    init(fromAssetId: String, toAssetId: String)
    func getMarketSources() -> [LiquiditySourceType]
    func getMarketSource(at index: Int) -> LiquiditySourceType?
    func isEmpty() -> Bool
    func isLoaded() -> Bool
    func didLoad(_ serverMarketSources: [String])
    func getServerMarketSources() -> [String]
    func index(of marketSource: LiquiditySourceType) -> Int?
    func contains(_ marketSource: LiquiditySourceType) -> Bool
}

class SwapMarketSourcer: SwapMarketSourcerProtocol {
    private var marketSources: [LiquiditySourceType]?
    private var fromAssetId: String
    private var toAssetId: String

    required init(fromAssetId: String, toAssetId: String) {
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
    }

    func getMarketSources() -> [LiquiditySourceType] {
        return marketSources ?? []
    }

    func getMarketSource(at index: Int) -> LiquiditySourceType? {
        guard let marketSources = marketSources, index < marketSources.count else {
            return nil
        }
        return marketSources[index]
    }

    func isEmpty() -> Bool {
        return marketSources?.isEmpty ?? true
    }

    func isLoaded() -> Bool {
        return marketSources != nil
    }

    func didLoad(_ serverMarketSources: [String]) {
        setMarketSources(from: serverMarketSources)
        forceAddSmartMarketSourceIfNecessary()
        addSmartIfNotEmpty()
    }

    func setMarketSources(_ marketSources: [LiquiditySourceType]) {
        self.marketSources = marketSources
    }

    func setMarketSources(from serverMarketSources: [String]) {
        marketSources = serverMarketSources.compactMap({LiquiditySourceType(rawValue: $0)})
    }

    func forceAddSmartMarketSourceIfNecessary() {
        if isEmpty() {
            add(.smart)
        }
    }

    func isXSTUSD(_ assetId: String) -> Bool {
        return assetId == WalletAssetId.xstusd.rawValue
    }

    func add(_ marketSource: LiquiditySourceType) {
        marketSources?.append(marketSource)
    }

    func addSmartIfNotEmpty() {
        guard let marketSources = marketSources else { return }

        let notEmpty = !marketSources.isEmpty
        let hasNoSmart = !marketSources.contains(.smart)
        if notEmpty && hasNoSmart {
            add(.smart)
        }
    }

    func getServerMarketSources() -> [String] {
        let filteredMarketSources = marketSources?.filter({shouldSendToServer($0)}) ?? []
        return filteredMarketSources.map({ $0.rawValue })
    }

    func shouldSendToServer(_ markerSource: LiquiditySourceType) -> Bool {
        return markerSource != .smart
    }

    func index(of marketSource: LiquiditySourceType) -> Int? {
        return marketSources?.firstIndex(where: { $0 == marketSource })
    }

    func contains(_ marketSource: LiquiditySourceType) -> Bool {
        return index(of: marketSource) != nil
    }
}
