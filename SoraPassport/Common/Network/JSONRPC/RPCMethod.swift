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
    static let dexInfos                     = "dexManager_dexInfos"
    
    static let accountPools                 = "PoolXYK_AccountPools"
    static let isPairEnabled                = "tradingPair_isPairEnabled"
}
