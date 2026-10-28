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
    let fiatData: [FiatData]
    let marketCapInfo: Set<MarketCapInfo>
}

protocol PriceInfoServiceProtocol: AnyObject {
    func setup(for assetIds: [String]) async
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo
}

actor PriceInfoService {
    static let shared = PriceInfoService()
    private var priceInfo: PriceInfo?
    private let fiatService = FiatService.shared
    private let marketCapService = MarketCapService.shared
    private var task: Task<Void, Swift.Error>?
    
    private func downloadInfo(for assetIds: [String]) async -> PriceInfo {
        async let fiatData = self.fiatService.getFiat()
        async let assetInfo = self.marketCapService.getMarketCap(for: assetIds)
        
        return await PriceInfo(fiatData: fiatData, marketCapInfo: assetInfo)
    }
}

extension PriceInfoService: PriceInfoServiceProtocol {
    
    func setup(for assetIds: [String]) async {
        priceInfo = await self.downloadInfo(for: assetIds)
    }
    
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo {
        if let priceInfo {
            let searchableInfo = Set(assetIds.map { MarketCapInfo(assetId: $0) })
            let result = searchableInfo.subtracting(priceInfo.marketCapInfo)
            
            if !result.isEmpty || priceInfo.fiatData.isEmpty {
                
                let priceInfo = await downloadInfo(for: assetIds)
                self.priceInfo = priceInfo
                return priceInfo
                
            } else {
                return priceInfo
            }
        }
        
        let priceInfo = await downloadInfo(for: assetIds)
        self.priceInfo = priceInfo
        return priceInfo
    }
}
