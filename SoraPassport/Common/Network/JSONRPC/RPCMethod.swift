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

enum RPCMethod {
    static let storageSubscribe = "state_subscribeStorage"
    static let chain = "system_chain"
    static let getStorage = "state_getStorage"
    static let getStorageKeysPaged = "state_getKeysPaged"
    static let queryStorageAt = "state_queryStorageAt"
    static let getBlockHash = "chain_getBlockHash"
    static let getHead = "chain_getFinalizedHead"
    static let getHeader = "chain_getHeader"
    static let submitExtrinsic = "author_submitExtrinsic"
    static let submitExtrinsicAndWatch = "author_submitAndWatchExtrinsic"
    static let paymentInfo = "payment_queryInfo"
    static let feeDetails = "payment_queryFeeDetails"
    static let getRuntimeVersion = "chain_getRuntimeVersion"
    static let getRuntimeMetadata = "state_getMetadata"
    static let getChainBlock = "chain_getBlock"
    static let getExtrinsicNonce = "system_accountNextIndex"
    static let helthCheck = "system_health"
    static let runtimeVersionSubscribe = "state_subscribeRuntimeVersion"
    static let freeBalance = "assets_freeBalance"
    static let assetInfo = "assets_listAssetInfos"
    static let needsMigration = "irohaMigration_needsMigration"
    static let usableBalance = "assets_usableBalance"

    // Polkaswap
    static let checkIsSwapPossible          = "liquidityProxy_isPathAvailable"
    static let availableMarketAlgorithms    = "liquidityProxy_listEnabledSourcesForPath"
    static let recalculateSwapValues        = "liquidityProxy_quote"
    static let swapExtrinsic                = "liquidityProxy_swap"
    
    static let accountPools                 = "PoolXYK_AccountPools"
    static let isPairEnabled                = "tradingPair_isPairEnabled"
}
