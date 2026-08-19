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
}

protocol PriceInfoServiceProtocol: AnyObject {
    func setup(for assetIds: [String]) async
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo
}

actor PriceInfoService {
    static let shared = PriceInfoService()

    private struct PendingDownload {
        let identifier = UUID()
        let assetIds: Set<String>
        let task: Task<PriceInfo, Never>
    }

    private var priceInfo: PriceInfo?
    private let fiatService = FiatService.shared
    private let marketCapService = MarketCapService.shared
    private var loadedAssetIds: Set<String> = []
    private var pendingDownload: PendingDownload?
    private var expirationDate = Date.distantPast

    private func createDownload(for assetIds: Set<String>) -> PendingDownload {
        let sortedAssetIds = assetIds.sorted()
        let fiatService = fiatService
        let marketCapService = marketCapService
        let task = Task<PriceInfo, Never> {
            async let fiatData = fiatService.getFiat(for: sortedAssetIds)
            async let assetInfo = marketCapService.getMarketCap(for: sortedAssetIds)

            return await PriceInfo(fiatData: fiatData, marketCapInfo: assetInfo)
        }

        return PendingDownload(assetIds: assetIds, task: task)
    }

    private func complete(_ download: PendingDownload) async {
        let downloadedPriceInfo = await download.task.value
        guard pendingDownload?.identifier == download.identifier else {
            return
        }

        pendingDownload = nil
        priceInfo = downloadedPriceInfo
        if !downloadedPriceInfo.fiatData.isEmpty {
            loadedAssetIds.formUnion(download.assetIds)
            expirationDate = Date().addingTimeInterval(600)
        }
    }
}

extension PriceInfoService: PriceInfoServiceProtocol {
    func setup(for assetIds: [String]) async {
        _ = await getPriceInfo(for: assetIds)
    }

    func getPriceInfo(for assetIds: [String]) async -> PriceInfo {
        let requestedAssetIds = Set(assetIds)
        var startedDownload = false

        while true {
            if expirationDate <= Date(), pendingDownload == nil {
                loadedAssetIds.removeAll()
            }

            if let priceInfo, requestedAssetIds.isSubset(of: loadedAssetIds) {
                return priceInfo
            }

            if let pendingDownload {
                let requestWasCovered = requestedAssetIds.isSubset(of: pendingDownload.assetIds)
                await complete(pendingDownload)
                if requestWasCovered {
                    startedDownload = true
                }
                continue
            }

            guard !startedDownload else {
                return priceInfo ?? PriceInfo(fiatData: [], marketCapInfo: [])
            }

            startedDownload = true
            let download = createDownload(for: loadedAssetIds.union(requestedAssetIds))
            pendingDownload = download
            await complete(download)
        }
    }
}
