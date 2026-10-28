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


protocol PolkaswapMainInteractorInputProtocol: AnyObject {
    func networkFeeValue(completion: @escaping (Decimal) -> Void)
    func checkIsPathAvailable(fromAssetId: String, toAssetId: String)
    func loadMarketSources(fromAssetId: String, toAssetId: String)
    func quote(params: PolkaswapMainInteractorQuoteParams)
    func loadBalance(asset: AssetInfo)
    func unsubscribePoolXYK()
    func unsubscribePoolTBC()
    func subscribePoolXYK(assetId1: String, assetId2: String)
    func subscribePoolTBC(assetId: String)
    func setup()
    func stop()
}

protocol PolkaswapMainInteractorOutputProtocol: AnyObject {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool)
    func didLoadMarketSources(_: [String], fromAssetId: String, toAssetId: String)
    func didLoadQuote(_: SwapValues?, dexId: UInt32, params: PolkaswapMainInteractorQuoteParams)
    func didLoadBalance(_: Decimal, asset: AssetInfo)
    func didUpdatePoolSubscription()
    func didUpdateBalance()
    func didCreateTransaction()
}

extension PolkaswapMainInteractorOutputProtocol {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {}
    func didLoadMarketSources(_ serverMarketSources: [String], fromAssetId: String, toAssetId: String) {}
    func didUpdateBalance() {}
    func didCreateTransaction() {}
    func didLoadBalance(_: Decimal, asset: AssetInfo) {}
}
