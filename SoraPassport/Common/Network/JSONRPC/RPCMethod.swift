/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
    static let getRuntimeVersion = "chain_getRuntimeVersion"
    static let getRuntimeMetadata = "state_getMetadata"
    static let getChainBlock = "chain_getBlock"
    static let getExtrinsicNonce = "system_accountNextIndex"
    static let helthCheck = "system_health"
    static let runtimeVersionSubscribe = "state_subscribeRuntimeVersion"
    static let freeBalance = "assets_freeBalance"
    static let assetInfo = "assets_listAssetInfos"
    static let needsMigration = "irohaMigration_needsMigration"
}
